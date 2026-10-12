#!/usr/bin/env python3
"""Publish builds and run Luau inside real Roblox servers via Open Cloud.

This is how Claude works on the game from a cloud session, where Roblox
Studio can't run: build the place with Rojo, upload it, then execute Luau
(tests, inspections, data fixes) on a headless Roblox server.

Environment variables:
  ROBLOX_API_KEY      Open Cloud API key. Permissions needed on the experience:
                        universe-places:write                      (publish)
                        universe.place.luau-execution-session:write (run)
                        universe.place.luau-execution-session:read  (run)
  ROBLOX_UNIVERSE_ID  Experience (universe) ID
  ROBLOX_PLACE_ID     Start place ID

Usage:
  scripts/roblox_cloud.py publish            # build + publish LIVE
  scripts/roblox_cloud.py publish --saved    # build + save a version (not live)
  scripts/roblox_cloud.py run tests/smoke.luau [--version N]
  scripts/roblox_cloud.py check              # save a version, run smoke tests on it
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://apis.roblox.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PLACE_FILE = os.path.join(ROOT, "build", "StealASlime.rbxlx")


def load_dotenv():
    """Read KEY=VALUE lines from a gitignored .env so secrets stay out of the shell."""
    path = os.path.join(ROOT, ".env")
    if not os.path.isfile(path):
        return
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip().strip("\"'"))


load_dotenv()


def env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"Missing environment variable {name} (see docs/SETUP.md)")
    return value


def request(method, url, body=None, content_type="application/json"):
    headers = {"x-api-key": env("ROBLOX_API_KEY")}
    data = None
    if body is not None:
        headers["Content-Type"] = content_type
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                text = resp.read().decode()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as err:
            detail = err.read().decode(errors="replace")
            if err.code in (429, 500, 502, 503, 504) and attempt < 4:
                time.sleep(2 ** (attempt + 1))
                continue
            sys.exit(f"{method} {url} failed: HTTP {err.code}\n{detail}")
        except urllib.error.URLError as err:
            if attempt < 4:
                time.sleep(2 ** (attempt + 1))
                continue
            sys.exit(f"{method} {url} failed: {err.reason}")
    sys.exit("unreachable")


def build(place_file):
    subprocess.run(["rojo", "build", os.path.join(ROOT, "default.project.json"), "-o", place_file], check=True)


def publish(place_file, saved):
    build(place_file)
    universe, place = env("ROBLOX_UNIVERSE_ID"), env("ROBLOX_PLACE_ID")
    version_type = "Saved" if saved else "Published"
    with open(place_file, "rb") as f:
        payload = f.read()
    url = f"{API}/universes/v1/{universe}/places/{place}/versions?versionType={version_type}"
    result = request("POST", url, payload, content_type="application/xml")
    version = result.get("versionNumber")
    print(f"{version_type} place version {version}")
    return version


def run_luau(script_path, version=None, timeout_s=300):
    universe, place = env("ROBLOX_UNIVERSE_ID"), env("ROBLOX_PLACE_ID")
    with open(script_path, encoding="utf-8") as f:
        script = f.read()
    base = f"{API}/cloud/v2/universes/{universe}/places/{place}"
    if version:
        base += f"/versions/{version}"
    task = request("POST", f"{base}/luau-execution-session-tasks", {"script": script, "timeout": f"{timeout_s}s"})
    path = task["path"]
    print(f"Task {path}")
    deadline = time.time() + timeout_s + 60
    while task.get("state") not in ("COMPLETE", "FAILED", "CANCELLED"):
        if time.time() > deadline:
            sys.exit("Timed out waiting for the Luau task")
        time.sleep(3)
        task = request("GET", f"{API}/cloud/v2/{path}")

    logs = request("GET", f"{API}/cloud/v2/{path}/logs?view=FLAT")
    for entry in logs.get("luauExecutionSessionTaskLogs", []):
        for message in entry.get("structuredMessages", []) or []:
            print(f"[{message.get('messageType', 'OUTPUT')}] {message.get('message', '')}")
        for message in entry.get("messages", []) or []:
            print(message)

    if task["state"] != "COMPLETE":
        error = task.get("error", {})
        sys.exit(f"Luau task {task['state']}: {error.get('code', '')} {error.get('message', '')}")
    results = task.get("output", {}).get("results", [])
    print("Results:", json.dumps(results, indent=2))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p_publish = sub.add_parser("publish", help="build and upload the place")
    p_publish.add_argument("--saved", action="store_true", help="save a version without making it live")
    p_publish.add_argument("--file", default=DEFAULT_PLACE_FILE)

    p_run = sub.add_parser("run", help="execute a Luau file on a Roblox server")
    p_run.add_argument("script")
    p_run.add_argument("--version", type=int)

    p_check = sub.add_parser("check", help="save a version and run the smoke tests against it")
    p_check.add_argument("--file", default=DEFAULT_PLACE_FILE)

    args = parser.parse_args()
    if args.command == "publish":
        publish(args.file, args.saved)
    elif args.command == "run":
        run_luau(args.script, args.version)
    elif args.command == "check":
        version = publish(args.file, saved=True)
        run_luau(os.path.join(ROOT, "tests", "smoke.luau"), version)


if __name__ == "__main__":
    main()
