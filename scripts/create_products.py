"""Create the game passes and developer products listed in
src/shared/Config/Monetization.luau on Roblox (Open Cloud), with their icons
from assets/monetization/<Key>.png, and write the new ids back into that
file. Items that already have an id are skipped, so it can be re-run.

    ROBLOX_API_KEY=...        (game-pass and developer-product write scopes)
    ROBLOX_UNIVERSE_ID=...

Both are read from .env if not set.

    python scripts/create_products.py [--only KEY]
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "shared", "Config", "Monetization.luau")
ICONS = os.path.join(ROOT, "assets", "monetization")
API = "https://apis.roblox.com"


def load_env():
    path = os.path.join(ROOT, ".env")
    if os.path.exists(path):
        for line in open(path, encoding="utf8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"'))


def multipart(fields, files):
    boundary = uuid.uuid4().hex
    body = b""
    for name, value in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode()
    for name, (filename, data) in files.items():
        body += (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{filename}\"\r\n"
            "Content-Type: image/png\r\n\r\n"
        ).encode() + data + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return body, f"multipart/form-data; boundary={boundary}"


def post(url, key, fields, files):
    body, content_type = multipart(fields, files)
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("x-api-key", key)
    req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as err:
        raise SystemExit(f"POST {url} failed: {err.code} {err.read().decode(errors='replace')}")


def entries(source, table):
    """(key, id, name, description, price) for each item in the local `table`."""
    block = re.search(rf"local {table}: \{{ \w+ \}} = \{{\n(.*?)\n\}}\n", source, re.S).group(1)
    items = []
    for chunk in re.findall(r"\t\{\n(.*?)\n\t\}", block, re.S):

        def field(name):
            m = re.search(rf"\b{name} = (\"(?:[^\"\\\\]|\\\\.)*\"|\d+)", chunk)
            if not m:
                return None
            return json.loads(m.group(1)) if m.group(1).startswith('"') else int(m.group(1))

        items.append((field("Key"), field("Id"), field("Name"), field("Description"), field("SuggestedPrice")))
    return items


def set_id(source, key, new_id):
    pattern = re.compile(rf"(Key = \"{key}\",\n\t\tId = )0,")
    updated, count = pattern.subn(rf"\g<1>{new_id},", source)
    if count != 1:
        raise SystemExit(f"could not write id for {key}")
    return updated


def icon(item_key):
    path = os.path.join(ICONS, f"{item_key}.png")
    return {"imageFile": (f"{item_key}.png", open(path, "rb").read())} if os.path.exists(path) else {}


def main():
    load_env()
    key = os.environ.get("ROBLOX_API_KEY")
    universe = os.environ.get("ROBLOX_UNIVERSE_ID")
    if not key or not universe:
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_UNIVERSE_ID (or put them in .env).")
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    source = open(CONFIG, encoding="utf8").read()

    for item_key, item_id, name, description, price in entries(source, "Passes"):
        if item_id or (only and only != item_key):
            continue
        result = post(
            f"{API}/game-passes/v1/universes/{universe}/game-passes",
            key,
            {"name": name, "description": description, "price": price, "isForSale": "true"},
            icon(item_key),
        )
        new_id = result.get("gamePassId") or result.get("id")
        if not new_id:
            raise SystemExit(f"{item_key}: no id in response {result}")
        print(f"pass {item_key}: {new_id}")
        source = set_id(source, item_key, new_id)
        open(CONFIG, "w", encoding="utf8", newline="\n").write(source)

    for item_key, item_id, name, description, price in entries(source, "Products"):
        if item_id or (only and only != item_key):
            continue
        result = post(
            f"{API}/developer-products/v2/universes/{universe}/developer-products",
            key,
            {"name": name, "description": description, "price": price, "isForSale": "true"},
            icon(item_key),
        )
        new_id = result.get("productId") or result.get("developerProductId") or result.get("id")
        if not new_id:
            raise SystemExit(f"{item_key}: no id in response {result}")
        print(f"product {item_key}: {new_id}")
        source = set_id(source, item_key, new_id)
        open(CONFIG, "w", encoding="utf8", newline="\n").write(source)


if __name__ == "__main__":
    main()
