import json
import os
import socket
import sys
import time
import urllib.error
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()
PI_AUTH = HOME / ".pi/agent/auth.json"
TIMEOUT = 10
CLAUDE_TOKEN_URL = "https://platform.claude.com/v1/oauth/token"
CLAUDE_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
LOCK_STALE_SECONDS = 30

def try_ipv4_before_possibly_unroutable_ipv6():
    resolve = socket.getaddrinfo
    socket.getaddrinfo = lambda *args, **kwargs: sorted(
        resolve(*args, **kwargs), key=lambda entry: entry[0] != socket.AF_INET)


try_ipv4_before_possibly_unroutable_ipv6()


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


CODEX_API = "https://chatgpt.com/backend-api/wham"


def get(url, headers, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, headers={
        "Accept": "application/json", **({"Content-Type": "application/json"} if data else {}), **headers})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return json.load(response)


def failure(reason):
    return {"available": False, "error": reason}


def window(percent, resets_at, severity=None):
    return {"percent": percent, "resetsAt": resets_at, "severity": severity}


def iso(epoch_seconds):
    return datetime.fromtimestamp(epoch_seconds, timezone.utc).isoformat()


@contextmanager
def pi_auth_lock():
    lock = PI_AUTH.with_name(PI_AUTH.name + ".lock")
    deadline = time.time() + LOCK_STALE_SECONDS
    while True:
        try:
            lock.mkdir()
            break
        except FileExistsError:
            try:
                if time.time() - lock.stat().st_mtime > LOCK_STALE_SECONDS:
                    lock.rmdir()
                    continue
            except FileNotFoundError:
                continue
            if time.time() > deadline:
                raise TimeoutError("auth.json is locked")
            time.sleep(0.05)
    try:
        yield
    finally:
        lock.rmdir()


def write_pi_auth(auth):
    staging = PI_AUTH.with_name(PI_AUTH.name + ".usage-tmp")
    staging.write_text(json.dumps(auth, indent=2))
    staging.chmod(0o600)
    os.replace(staging, PI_AUTH)


def renew_pi_claude_login():
    with pi_auth_lock():
        auth = read_json(PI_AUTH) or {}
        login = auth.get("anthropic") or {}
        if not expired(login.get("expires")):
            return login
        if not login.get("refresh"):
            return None
        try:
            data = get(CLAUDE_TOKEN_URL, {"User-Agent": "agent-usage"}, {
                "grant_type": "refresh_token",
                "client_id": CLAUDE_CLIENT_ID,
                "refresh_token": login["refresh"],
            })
        except urllib.error.HTTPError:
            return None
        login = {**login, "type": "oauth", "access": data["access_token"],
                 "refresh": data.get("refresh_token") or login["refresh"],
                 "expires": int(time.time() * 1000) + data["expires_in"] * 1000 - 5 * 60 * 1000}
        write_pi_auth({**auth, "anthropic": login})
        return login


def claude_login():
    pi = (read_json(PI_AUTH) or {}).get("anthropic") or {}
    if pi.get("access") and expired(pi.get("expires")):
        pi = renew_pi_claude_login() or pi
    if pi.get("access"):
        return pi["access"], pi.get("expires")
    code = (read_json(HOME / ".claude/.credentials.json") or {}).get("claudeAiOauth") or {}
    if code.get("accessToken"):
        return code["accessToken"], code.get("expiresAt")
    return None, None


def codex_login():
    pi = (read_json(PI_AUTH) or {}).get("openai-codex") or {}
    if pi.get("access"):
        return pi["access"], pi.get("accountId"), pi.get("expires")
    tokens = (read_json(HOME / ".codex/auth.json") or {}).get("tokens") or {}
    if tokens.get("access_token"):
        return tokens["access_token"], tokens.get("account_id"), None
    return None, None, None


def expired(expires_ms):
    return expires_ms is not None and expires_ms / 1000 <= time.time()


def claude():
    token, expires = claude_login()
    if not token:
        return failure("not signed in")
    if expired(expires):
        return failure("login expired")
    data = get("https://api.anthropic.com/api/oauth/usage", {
        "Authorization": "Bearer " + token,
        "anthropic-beta": "oauth-2025-04-20",
    })
    limits = data.get("limits") or []
    severity = {limit.get("kind"): limit.get("severity") for limit in limits}
    five_hour = data.get("five_hour") or {}
    seven_day = data.get("seven_day") or {}
    return {
        "available": True,
        "fiveHour": window(five_hour.get("utilization"), five_hour.get("resets_at"), severity.get("session")),
        "weekly": window(seven_day.get("utilization"), seven_day.get("resets_at"), severity.get("weekly_all")),
        "models": [
            {"name": (limit.get("scope") or {}).get("model", {}).get("display_name") or "Model",
             **window(limit.get("percent"), limit.get("resets_at"), limit.get("severity"))}
            for limit in limits if limit.get("kind") == "weekly_scoped"
        ],
    }


def codex_headers():
    token, account, expires = codex_login()
    if not token:
        return None, "not signed in"
    if expired(expires):
        return None, "login expired"
    headers = {"Authorization": "Bearer " + token, "User-Agent": "codex_cli_rs"}
    if account:
        headers["chatgpt-account-id"] = account
    return headers, None


def codex_resets(headers, summary):
    summary = summary or {}
    available = summary.get("available_count") or 0
    credits = []
    if available:
        listing = get(CODEX_API + "/rate-limit-reset-credits", headers)
        credits = [
            {"id": credit.get("id"), "title": credit.get("title"), "expiresAt": credit.get("expires_at")}
            for credit in listing.get("credits") or []
            if credit.get("status") == "available" and credit.get("is_supported_by_plan", True)
        ]
    return {"available": available, "applicable": summary.get("applicable_available_count") or 0,
            "credits": credits}


def codex():
    headers, reason = codex_headers()
    if reason:
        return failure(reason)
    data = get(CODEX_API + "/usage", headers)
    limits = data.get("rate_limit") or {}

    def from_window(entry):
        entry = entry or {}
        return window(entry.get("used_percent"), iso(entry["reset_at"]) if entry.get("reset_at") else None)

    return {
        "available": True,
        "plan": data.get("plan_type"),
        "limited": limits.get("allowed") is False,
        "fiveHour": from_window(limits.get("primary_window")),
        "weekly": from_window(limits.get("secondary_window")),
        "models": [],
        "resets": codex_resets(headers, data.get("rate_limit_reset_credits")),
    }


def reset_codex(credit_id=None):
    headers, reason = codex_headers()
    if reason:
        return failure(reason)
    body = {"redeem_request_id": str(uuid.uuid4())}
    if credit_id:
        body["credit_id"] = credit_id
    data = get(CODEX_API + "/rate-limit-reset-credits/consume", headers, body) or {}
    return {"available": True, "outcome": data.get("outcome") or data.get("status") or "reset"}


def safely(provider):
    try:
        return provider()
    except urllib.error.HTTPError as error:
        return failure("login rejected" if error.code in (401, 403) else "HTTP " + str(error.code))
    except (urllib.error.URLError, TimeoutError, OSError):
        return failure("unreachable")
    except (ValueError, KeyError, TypeError, AttributeError):
        return failure("unexpected response")


def main():
    if sys.argv[1:2] == ["reset-codex"]:
        json.dump(safely(lambda: reset_codex(sys.argv[2] if len(sys.argv) > 2 else None)), sys.stdout)
        sys.stdout.write("\n")
        return
    if sys.argv[1:2] == ["--stream"]:
        with ThreadPoolExecutor(max_workers=2) as pool:
            pending = {pool.submit(safely, provider): name
                       for name, provider in [("claude", claude), ("codex", codex)]}
            for future in as_completed(pending):
                print(json.dumps({"checkedAt": datetime.now(timezone.utc).isoformat(),
                                  pending[future]: future.result()}), flush=True)
        return
    with ThreadPoolExecutor(max_workers=2) as pool:
        claude_result, codex_result = pool.map(safely, [claude, codex])
    json.dump({"checkedAt": datetime.now(timezone.utc).isoformat(), "claude": claude_result, "codex": codex_result},
              sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
