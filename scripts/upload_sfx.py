"""Upload the ElevenLabs sounds in assets/sfx to Roblox as audio assets and
write their ids into src/shared/Config/Sounds.luau (the `Uploaded` table).

Needs an Open Cloud API key with the Assets API (asset:read, asset:write)
scope, and the creator to upload as:

    ROBLOX_API_KEY=...                  (required)
    ROBLOX_CREATOR_USER_ID=123456       (or ROBLOX_CREATOR_GROUP_ID)

Both may also live in a .env file next to this repo. Sounds that already
have an id are skipped, so the script can be re-run after a failure.

    python scripts/upload_sfx.py
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS = os.path.join(ROOT, "src", "shared", "Config", "Sounds.luau")
SFX = os.path.join(ROOT, "assets", "sfx")
API = "https://apis.roblox.com/assets/v1"

# Sounds never to upload (e.g. ones moderation rejected).
NEVER_UPLOAD: set = set()


def load_env():
    path = os.path.join(ROOT, ".env")
    if os.path.exists(path):
        for line in open(path, encoding="utf8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip().strip('"'))


def request(method, url, key, body=None, content_type=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as err:
        raise SystemExit(f"{method} {url} failed: {err.code} {err.read().decode(errors='replace')}")


def upload(key, creator, name, path):
    meta = {
        "assetType": "Audio",
        "displayName": f"Slime {name}",
        "description": "Steal a Slime sound effect",
        "creationContext": {"creator": creator},
    }
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        audio = f.read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n".encode()
        + json.dumps(meta).encode()
        + f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.mp3\"\r\n"
        f"Content-Type: audio/mpeg\r\n\r\n".encode()
        + audio
        + f"\r\n--{boundary}--\r\n".encode()
    )
    op = request("POST", f"{API}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    path_id = op.get("path", "")
    for _ in range(60):
        if op.get("done"):
            asset = op.get("response", {}).get("assetId")
            if not asset:
                raise SystemExit(f"{name}: upload finished without an asset id: {op}")
            return int(asset)
        time.sleep(2)
        op = request("GET", f"{API}/{path_id}", key)
    raise SystemExit(f"{name}: timed out waiting for {path_id}")


def main():
    load_env()
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        sys.exit("Set ROBLOX_API_KEY (Assets API scope).")
    if os.environ.get("ROBLOX_CREATOR_GROUP_ID"):
        creator = {"groupId": os.environ["ROBLOX_CREATOR_GROUP_ID"]}
    elif os.environ.get("ROBLOX_CREATOR_USER_ID"):
        creator = {"userId": os.environ["ROBLOX_CREATOR_USER_ID"]}
    else:
        sys.exit("Set ROBLOX_CREATOR_USER_ID or ROBLOX_CREATOR_GROUP_ID.")

    source = open(SOUNDS, encoding="utf8").read()
    def block(name):
        match = re.search(rf"local {name}: [^\n]*= {{\n(.*?)\n}}", source, re.S)
        return match.group(1) if match else ""

    files = dict(re.findall(r"^\t(\w+) = \"(\w+)\",$", block("Files"), re.M))
    uploaded = dict(re.findall(r"^\t(\w+) = (\d+),$", block("Uploaded"), re.M))

    for name, file in files.items():
        if uploaded.get(name, "0") != "0" or name in NEVER_UPLOAD:
            continue
        path = os.path.join(SFX, file + ".mp3")
        if not os.path.exists(path):
            print(f"skip {name}: {path} missing")
            continue
        asset = upload(key, creator, name, path)
        print(f"{name}: {asset}")
        source = re.sub(rf"^(\t{name} = )0,$", rf"\g<1>{asset},", source, count=1, flags=re.M)
        open(SOUNDS, "w", encoding="utf8", newline="\n").write(source)


if __name__ == "__main__":
    main()
