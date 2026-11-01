"""Toggle Mozc's native Hiragana/Katakana action without injecting modified keys."""
import json
import subprocess
import sys


def query(*arguments):
    result = subprocess.check_output(
        ["busctl", "--user", "--json=short", "--", *arguments], text=True,
    )
    return json.loads(result)["data"]


def menu_nodes(node):
    yield node
    for child in node[2]:
        yield from menu_nodes(child["data"])


def main():
    engine = query("call", "org.fcitx.Fcitx5", "/controller",
                   "org.fcitx.Fcitx.Controller1", "CurrentInputMethod")[0]
    if engine != "mozc":
        return

    items = query("get-property", "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
                  "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
    for item in items:
        service, path = item.split("/", 1)
        path = "/" + path
        if query("get-property", service, path, "org.kde.StatusNotifierItem", "Id") == "Fcitx":
            break
    else:
        sys.exit("Fcitx's tray menu is unavailable; Quickshell must be running.")

    menu = query("get-property", service, path, "org.kde.StatusNotifierItem", "Menu")
    query("call", service, menu, "com.canonical.dbusmenu", "AboutToShow", "i", "0")
    layout = query("call", service, menu, "com.canonical.dbusmenu",
                   "GetLayout", "iias", "0", "-1", "0")[1]
    modes = {
        properties["icon-name"]["data"]: (node_id, properties)
        for node_id, properties, _ in menu_nodes(layout)
        if "icon-name" in properties
    }
    hiragana = modes.get("fcitx_mozc_hiragana")
    katakana = modes.get("fcitx_mozc_katakana_full")
    if hiragana is None or katakana is None:
        sys.exit("Mozc kana actions are unavailable. Focus an editable text field first.")
    target = katakana if hiragana[1]["toggle-state"]["data"] == 1 else hiragana
    subprocess.run([
        "busctl", "--user", "--", "call", service, menu, "com.canonical.dbusmenu",
        "Event", "isvu", str(target[0]), "clicked", "i", "0", "0",
    ], check=True)


if __name__ == "__main__":
    main()
