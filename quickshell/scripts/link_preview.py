#!/usr/bin/env python3
import hashlib
import http.client
import ipaddress
import json
import os
import socket
import ssl
import sys
import time
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit

PAGE_LIMIT = 600_000
IMAGE_LIMIT = 5_000_000
MAX_REDIRECTS = 5
DEADLINE_SECONDS = 15
IMAGE_TYPES = {"image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif", "image/webp": ".webp"}


class Refused(Exception):
    pass


def public_address(host, port):
    addresses = {info[4][0] for info in socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)}
    if not addresses:
        raise Refused(f"{host} has no address")
    for address in addresses:
        if not ipaddress.ip_address(address.split("%")[0]).is_global:
            raise Refused(f"{host} resolves to non-public address {address}")
    return sorted(addresses)[0]


class PinnedConnection(http.client.HTTPSConnection):
    def __init__(self, host, port, address, secure, timeout):
        super().__init__(host, port, timeout=timeout, context=ssl.create_default_context())
        self.address = address
        self.secure = secure
        self.default_port = 443 if secure else 80

    def connect(self):
        self.sock = socket.create_connection((self.address, self.port), self.timeout)
        if self.secure:
            self.sock = self._context.wrap_socket(self.sock, server_hostname=self.host)


def get(url, accept, limit, deadline):
    for _ in range(MAX_REDIRECTS + 1):
        parts = urlsplit(url)
        if parts.scheme not in ("http", "https") or not parts.hostname:
            raise Refused(f"unsupported URL {url}")
        secure = parts.scheme == "https"
        port = parts.port or (443 if secure else 80)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError(f"timed out fetching {url}")
        connection = PinnedConnection(parts.hostname, port, public_address(parts.hostname, port), secure, remaining)
        try:
            path = (parts.path or "/") + (f"?{parts.query}" if parts.query else "")
            connection.request("GET", path, headers={"User-Agent": "Mozilla/5.0", "Accept": accept})
            response = connection.getresponse()
            if response.status in (301, 302, 303, 307, 308) and response.getheader("Location"):
                url = urljoin(url, response.getheader("Location"))
                continue
            if response.status != 200:
                raise Refused(f"HTTP {response.status} from {url}")
            body = bytearray()
            while len(body) < limit:
                if time.monotonic() > deadline:
                    raise TimeoutError(f"timed out reading {url}")
                chunk = response.read(min(65536, limit - len(body)))
                if not chunk:
                    break
                body += chunk
            return url, response.getheader("Content-Type", ""), bytes(body)
        finally:
            connection.close()
    raise Refused(f"too many redirects from {url}")


class PageMeta(HTMLParser):
    def __init__(self):
        super().__init__()
        self.meta = {}
        self.title = ""
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "title":
            self.in_title = True
        elif tag == "meta":
            key = (attrs.get("property") or attrs.get("name") or "").lower()
            if key and key not in self.meta:
                self.meta[key] = (attrs.get("content") or "").strip()

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data


def charset(content_type):
    for part in content_type.split(";")[1:]:
        key, _, value = part.strip().partition("=")
        if key.lower() == "charset" and value:
            return value.strip("\"'")
    return "utf-8"


def cached_image(url, deadline):
    _, content_type, body = get(url, "image/*", IMAGE_LIMIT, deadline)
    extension = IMAGE_TYPES.get(content_type.split(";")[0].strip().lower())
    if not extension:
        raise Refused(f"{url} is not a supported image ({content_type})")
    cache = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "quickshell/link-previews"
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / (hashlib.sha256(url.encode()).hexdigest() + extension)
    temporary = target.with_suffix(".tmp")
    temporary.write_bytes(body)
    temporary.replace(target)
    return target.as_uri()


def preview(url):
    deadline = time.monotonic() + DEADLINE_SECONDS
    final_url, content_type, body = get(url, "text/html", PAGE_LIMIT, deadline)
    if "html" not in content_type.lower():
        return None
    page = PageMeta()
    page.feed(body.decode(charset(content_type), errors="replace"))
    meta = page.meta
    title = meta.get("og:title") or meta.get("twitter:title") or page.title.strip()
    image_link = meta.get("og:image") or meta.get("twitter:image")
    image = ""
    if image_link:
        try:
            image = cached_image(urljoin(final_url, image_link), deadline)
        except (OSError, Refused, http.client.HTTPException) as error:
            print(f"link-preview: no image: {error}", file=sys.stderr)
    if not title and not image:
        return None
    return {
        "site": meta.get("og:site_name") or urlsplit(final_url).hostname.removeprefix("www."),
        "title": title,
        "description": meta.get("og:description") or meta.get("twitter:description") or meta.get("description") or "",
        "image": image,
    }


if __name__ == "__main__":
    try:
        print(json.dumps(preview(sys.argv[1])))
    except (OSError, Refused, http.client.HTTPException, UnicodeError, LookupError) as error:
        print(f"link-preview: {error}", file=sys.stderr)
        sys.exit(1)
