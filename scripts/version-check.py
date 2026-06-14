#!/usr/bin/env python3
"""Compare the packaged version of each package against its upstream latest.

Run from the repository root:  scripts/version-check.py

For every package the currently packaged (upstream) version is read from
packages/<pkg>/debian/changelog.  The latest upstream version is then looked
up using a per-package method:

  pypi           - https://pypi.org/pypi/<name>/json
  github_release - latest non-draft release tag of a GitHub repo
  github_tag     - highest semver-looking tag of a GitHub repo
  track          - opaque/manual sources (binary build-ids, vendor sites,
                   pinned git commits); reported for manual review only

Exit status is non-zero if any auto-trackable package is behind, so CI can
turn the output into an issue or PR.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# package -> (method, *args)
SOURCES = {
    "eventb-to-txt":  ("pypi", "eventb-to-txt"),
    "evbt":           ("github_tag", "viklauverk", "EventBTool"),
    "eventb-checker": ("github_release", "eventb-rossi", "eventb-checker"),
    "eventb-animate": ("github_release", "eventb-rossi", "eventb-animate"),
    "tlc4b":          ("github_tag", "hhu-stups", "tlc4b"),
    "b2program":      ("track", "favu100/b2program @ master (pinned commit)"),
    "prob2-ui":       ("track", "https://prob.hhu.de (prob2 downloads)"),
    "prob":           ("track", "https://prob.hhu.de (ProB Tcl/Tk releases)"),
    "rodin":          ("track", "SourceForge rodin-b-sharp (opaque build id)"),
    "rodin-rc":       ("track", "SourceForge rodin-b-sharp (RC, opaque build id)"),
    "atelier-b":      ("track", "https://www.atelierb.eu (vendor .deb)"),
}

def _get_json(url: str):
    headers = {"User-Agent": "eventb-ubuntu-version-check"}
    # Authenticate GitHub API calls when a token is available, to avoid the
    # 60-requests/hour anonymous rate limit (which would otherwise turn every
    # GitHub-tracked package into an error row).
    token = os.environ.get("GITHUB_TOKEN")
    if token and "api.github.com" in url:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def packaged_version(pkg: str) -> str | None:
    changelog = ROOT / "packages" / pkg / "debian" / "changelog"
    if not changelog.exists():
        return None
    out = subprocess.check_output(
        ["dpkg-parsechangelog", "-l", str(changelog), "-S", "Version"], text=True
    ).strip()
    upstream = out.rsplit("-", 1)[0]      # drop debian revision
    return upstream.split(":", 1)[-1]     # drop epoch


def _norm_tag(tag: str) -> str:
    return re.sub(r"^v", "", tag.strip())


def latest_pypi(name: str) -> str:
    return _get_json(f"https://pypi.org/pypi/{name}/json")["info"]["version"]


def latest_github_release(owner: str, repo: str) -> str:
    data = _get_json(f"https://api.github.com/repos/{owner}/{repo}/releases/latest")
    return _norm_tag(data["tag_name"])


def latest_github_tag(owner: str, repo: str) -> str:
    data = _get_json(f"https://api.github.com/repos/{owner}/{repo}/tags?per_page=100")
    best = None
    for t in data:
        v = _norm_tag(t["name"])
        if re.match(r"^[0-9]+(\.[0-9]+)*$", v):
            key = tuple(int(x) for x in v.split("."))
            if best is None or key > best[0]:
                best = (key, v)
    return best[1] if best else "?"


# Auto-trackable methods -> the function that returns the latest upstream
# version.  Each is called with the remaining entries of its SOURCES tuple.
HANDLERS = {
    "pypi": latest_pypi,
    "github_release": latest_github_release,
    "github_tag": latest_github_tag,
}


def main() -> int:
    behind = 0
    print(f"{'package':16} {'packaged':22} {'upstream':22} status")
    print("-" * 70)
    for pkg, (method, *params) in SOURCES.items():
        cur = packaged_version(pkg) or "?"
        if method == "track":
            print(f"{pkg:16} {cur:22} {'(manual)':22} track: {params[0]}")
            continue
        try:
            latest = HANDLERS[method](*params)
        except Exception as exc:  # noqa: BLE001
            print(f"{pkg:16} {cur:22} {'ERROR':22} {exc}")
            continue

        status = "ok" if latest == cur else "BEHIND"
        if status == "BEHIND":
            behind += 1
        print(f"{pkg:16} {cur:22} {latest:22} {status}")

    print("-" * 70)
    print(f"{behind} package(s) behind upstream")
    return 1 if behind else 0


if __name__ == "__main__":
    sys.exit(main())
