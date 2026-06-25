#!/usr/bin/env python3
"""Upstream version monitor for the eventb-rossi APT package set.

Two responsibilities, mirroring gentoo-overlay's version-check and
homebrew-tap's release tracker:

  * "bump" packages have a get-orig.sh whose download URL is derived purely
    from ${UVER} (the changelog version), so a version bump is mechanical and
    touches only debian/changelog: prepend a new stanza. get-orig.sh and the
    build pick up the new version automatically. These are turned into PRs.

  * "track" packages embed an opaque build id (rodin), a release-candidate
    build id (rodin-rc), or a dated vendor path (atelier-b) that the version
    number alone can't reconstruct, so they can't be bumped blindly. We only
    detect the new version and file a GitHub issue for a human to handle.

Subcommands:
  check        Print a JSON report of every package (current/latest/outdated).
  bump <pkg>   For one outdated "bump" package, rewrite debian/changelog in
               place. No-op (exit 0) if already up to date.
"""

from __future__ import annotations

import datetime
import email.utils
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Changelog author for automated bumps (matches the existing changelog trailers).
CHANGELOG_AUTHOR = "Denis Efremov <efremov@linux.com>"

# --- package configuration -------------------------------------------------
# mode: "bump"  -> auto-bump into a PR (get-orig.sh URL is ${UVER}-derived, so
#                  only debian/changelog changes)
#       "track" -> detect only, file an issue (opaque build id / dated path)
#       "skip"  -> not monitored (pinned-commit snapshot)
#
# source.type:
#   pypi           -> latest release of a PyPI project
#   github         -> latest non-prerelease GitHub release, else highest tag
#   maven          -> latest release in a Maven repo's maven-metadata.xml
#   apache_index   -> newest X.Y.Z subdirectory in an Apache/nginx autoindex
#   sourceforge    -> newest plain X.Y.Z version dir under a SourceForge path
#   sourceforge_rc -> newest X.Y[.Z]-RCn dir under a SourceForge path
#   atelierb       -> scrape the Atelier B download page for the free version
PACKAGES = [
    {"pkg": "eventb-to-txt", "mode": "bump",
     "source": {"type": "pypi", "name": "eventb-to-txt"}},
    {"pkg": "evbt", "mode": "bump",
     "source": {"type": "github", "repo": "viklauverk/EventBTool"}},
    {"pkg": "eventb-checker", "mode": "bump",
     "source": {"type": "github", "repo": "eventb-rossi/eventb-checker"}},
    {"pkg": "eventb-animate", "mode": "bump",
     "source": {"type": "github", "repo": "eventb-rossi/eventb-animate"}},
    {"pkg": "rossi", "mode": "bump",
     "source": {"type": "github", "repo": "eventb-rossi/rossi"}},
    {"pkg": "rodin-headless", "mode": "bump",
     "source": {"type": "github", "repo": "eventb-rossi/rodin-headless"}},
    # get-orig.sh resolves the jar (and its dependency closure) from Maven
    # Central, so detect there too -- a GitHub tag without a published Maven
    # artifact would otherwise open a bump PR that can't build.
    {"pkg": "tlc4b", "mode": "bump",
     "source": {"type": "maven", "group": "de.hhu.stups", "artifact": "tlc4b"}},
    # The version directory lives on the same host the distfile is fetched from,
    # so a detected version implies its release dir (and artifact) exists.
    {"pkg": "prob", "mode": "bump",
     "source": {"type": "apache_index",
                "url": "https://stups.hhu-hosting.de/downloads/prob/tcltk/releases/"}},
    {"pkg": "prob2-ui", "mode": "bump",
     "source": {"type": "apache_index",
                "url": "https://stups.hhu-hosting.de/downloads/prob2/"}},

    {"pkg": "rodin", "mode": "track",
     "source": {"type": "sourceforge", "project": "rodin-b-sharp",
                "path": "/Core_Rodin_Platform"}},
    {"pkg": "rodin-rc", "mode": "track",
     "source": {"type": "sourceforge_rc", "project": "rodin-b-sharp",
                "path": "/Core_Rodin_Platform"}},
    {"pkg": "atelier-b", "mode": "track",
     "source": {"type": "atelierb",
                "url": "https://www.atelierb.eu/en/atelier-b-support-maintenance/download-atelier-b/"}},

    {"pkg": "b2program", "mode": "skip", "source": {}},
]

UA = {"User-Agent": "eventb-rossi-apt-version-check/1 (+https://github.com/eventb-rossi/apt)"}


# --- helpers ---------------------------------------------------------------
def http_get(url: str, *, headers: dict | None = None, timeout: int = 60) -> bytes:
    req = urllib.request.Request(url, headers={**UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def gh_headers() -> dict:
    h = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


# Leading dotted-numeric run of a version-ish string (drops a v-prefix / suffix).
VERSION_RE = re.compile(r"\d+(?:\.\d+)*")
RC_RE = re.compile(r"[-_.]?RC(\d+)", re.IGNORECASE)


def version_tuple(s: str) -> tuple[int, ...]:
    """`s` as ints, e.g. 'v3.10.0_rc2' -> (3,10,0). Numeric, not lexical."""
    m = VERSION_RE.search(s)
    return tuple(int(p) for p in m.group(0).split(".")) if m else ()


def _padded_pair(latest: str, current: str) -> tuple[tuple[int, ...], tuple[int, ...]]:
    """Both versions as numeric tuples zero-padded to equal length.

    Padding means a shorter string isn't treated as older than its own
    longer-but-equal form (3.10 == 3.10.0, while 3.10 > 3.9.0).
    """
    a, b = version_tuple(latest), version_tuple(current)
    n = max(len(a), len(b))
    return a + (0,) * (n - len(a)), b + (0,) * (n - len(b))


def version_newer(latest: str, current: str) -> bool:
    """True if `latest` is a newer release than `current` (suffixes ignored)."""
    a, b = _padded_pair(latest, current)
    return a > b


def rc_num(s: str) -> int:
    """Trailing RC number of a version string, e.g. '3.10-RC2' -> 2 (0 if none)."""
    m = RC_RE.search(s)
    return int(m.group(1)) if m else 0


def version_newer_rc(latest: str, current: str) -> bool:
    """RC-aware comparison: compare the (padded) base first, then the RC number.

    Padding makes a SourceForge `3.10-RC2` (base (3,10)) and a packaged
    `3.10.0~rc2` (base (3,10,0)) count as the same base, so a same-base RC bump
    (RC2 -> RC3) is caught instead of falling through to the RC-blind base
    comparison.
    """
    a, b = _padded_pair(latest, current)
    if a != b:
        return a > b
    return rc_num(latest) > rc_num(current)


def clean_pv(tag: str) -> str:
    """Upstream tag -> dotted version, e.g. 'v1.4' -> '1.4'. Empty if no number."""
    m = VERSION_RE.search(tag)
    return m.group(0) if m else ""


# --- current (packaged) version -------------------------------------------
# Top changelog line, e.g. "eventb-checker (1.6-1) noble; urgency=medium".
# Parsing the first stanza directly avoids a dpkg-dev dependency in CI.
CHANGELOG_TOP_RE = re.compile(
    r"^(?P<src>\S+)\s+\((?P<ver>[^)]+)\)\s+(?P<dist>[^;]+);\s*urgency=(?P<urg>\S+)")


def current_stanza(pkg: str) -> dict | None:
    """Source/version/distribution/urgency from the top of debian/changelog.

    The version has any epoch (`N:`) and Debian revision (`-N`) stripped, so it
    matches the upstream version that get-orig.sh consumes as ${UVER}.
    """
    changelog = ROOT / "packages" / pkg / "debian" / "changelog"
    if not changelog.exists():
        return None
    first = ""
    with changelog.open() as fh:
        for line in fh:
            if line.strip():
                first = line
                break
    m = CHANGELOG_TOP_RE.match(first)
    if not m:
        return None
    raw = m.group("ver")
    epoch, rest = raw.split(":", 1) if ":" in raw else ("", raw)
    ver = rest.rsplit("-", 1)[0]             # drop debian revision
    return {"source": m.group("src"), "epoch": epoch, "version": ver,
            "distribution": m.group("dist").strip(), "urgency": m.group("urg")}


def current_version(pkg: str) -> str | None:
    s = current_stanza(pkg)
    return s["version"] if s else None


# --- latest (upstream) version --------------------------------------------
PRERELEASE_RE = re.compile(r"(?:^|[-_.])(?:rc|alpha|beta|pre|dev|snapshot)(?=\d|[-_.]|$)",
                           re.IGNORECASE)


def latest_pypi(name: str) -> str:
    return json.loads(http_get(f"https://pypi.org/pypi/{name}/json"))["info"]["version"]


def latest_github(repo: str) -> str:
    """Latest release tag, falling back to the highest stable tag."""
    try:
        data = json.loads(http_get(f"https://api.github.com/repos/{repo}/releases/latest",
                                   headers=gh_headers()))
        return clean_pv(data["tag_name"])
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise
    tags = json.loads(http_get(f"https://api.github.com/repos/{repo}/tags?per_page=100",
                               headers=gh_headers()))
    names = [t["name"] for t in tags if not PRERELEASE_RE.search(t["name"])]
    if not names:
        raise ValueError(f"{repo}: no stable tags found")
    return clean_pv(max(names, key=version_tuple))


def latest_maven(group: str, artifact: str) -> str:
    """Latest release version from a Maven repository's maven-metadata.xml."""
    g = group.replace(".", "/")
    xml = http_get(
        f"https://repo1.maven.org/maven2/{g}/{artifact}/maven-metadata.xml"
    ).decode("utf-8", "replace")
    m = re.search(r"<release>([^<]+)</release>", xml)
    if m:
        return m.group(1)
    # Some metadata omits <release>; fall back to the highest stable <version>.
    versions = [v for v in re.findall(r"<version>([^<]+)</version>", xml)
                if not PRERELEASE_RE.search(v)]
    if not versions:
        raise ValueError(f"no versions in maven-metadata for {group}:{artifact}")
    return max(versions, key=version_tuple)


def _scrape_max(url: str, pattern: str, what: str, *, flags: int = 0,
                key=version_tuple) -> str:
    """Fetch `url`, regex-`findall` version strings, return the newest by `key`.

    Raises ValueError(`what`) when the page matched nothing.
    """
    page = http_get(url).decode("utf-8", "replace")
    versions = re.findall(pattern, page, flags)
    if not versions:
        raise ValueError(what)
    return max(versions, key=key)


def latest_sourceforge(project: str, path: str) -> str:
    """Newest plain version directory directly under a SourceForge files path."""
    pat = re.escape(path.rstrip("/")) + r"/(\d+(?:\.\d+)*)/"
    return _scrape_max(f"https://sourceforge.net/projects/{project}/rss?path={path}",
                       pat, f"no versions matched under {path}")


def latest_sourceforge_rc(project: str, path: str) -> str:
    """Newest X.Y[.Z]-RCn release-candidate directory under a SourceForge path."""
    pat = re.escape(path.rstrip("/")) + r"/(\d+(?:\.\d+)*-RC\d+)/"
    return _scrape_max(f"https://sourceforge.net/projects/{project}/rss?path={path}",
                       pat, f"no release-candidate versions matched under {path}",
                       flags=re.IGNORECASE,
                       key=lambda v: (version_tuple(v), rc_num(v)))


def latest_atelierb(url: str) -> str:
    return _scrape_max(url, r"atelierb-free-(\d+(?:\.\d+)+)-",
                       "no atelierb-free-<version> link found")


def latest_apache_index(url: str) -> str:
    """Newest multi-component version subdirectory in an Apache/nginx autoindex."""
    return _scrape_max(url, r'href="(\d+(?:\.\d+)+)/"',
                       f"no version directories found at {url}")


def latest_version(source: dict) -> str:
    t = source["type"]
    if t == "pypi":
        return latest_pypi(source["name"])
    if t == "github":
        return latest_github(source["repo"])
    if t == "maven":
        return latest_maven(source["group"], source["artifact"])
    if t == "apache_index":
        return latest_apache_index(source["url"])
    if t == "sourceforge":
        return latest_sourceforge(source["project"], source["path"])
    if t == "sourceforge_rc":
        return latest_sourceforge_rc(source["project"], source["path"])
    if t == "atelierb":
        return latest_atelierb(source["url"])
    raise ValueError(f"unknown source type {t!r}")


def is_outdated(source: dict, latest: str | None, current: str | None) -> bool:
    if not (latest and current):
        return False
    if source.get("type") == "sourceforge_rc":
        return version_newer_rc(latest, current)
    return version_newer(latest, current)


# --- subcommands -----------------------------------------------------------
def cmd_check() -> int:
    report = []
    for pkg in PACKAGES:
        entry = {"pkg": pkg["pkg"], "mode": pkg["mode"], "current": None,
                 "latest": None, "outdated": False, "error": None}
        # Best-effort per package: a malformed changelog or a network blip
        # records an error for that entry but never aborts the whole report.
        try:
            entry["current"] = current_version(pkg["pkg"])
            if pkg["mode"] != "skip":
                latest = latest_version(pkg["source"])
                entry["latest"] = latest
                entry["outdated"] = is_outdated(pkg["source"], latest, entry["current"])
        except Exception as exc:
            entry["error"] = f"{type(exc).__name__}: {exc}"
        report.append(entry)
    print(json.dumps(report, indent=2))
    return 0


def emit_outputs(**kv: str) -> None:
    """Append key=value lines to $GITHUB_OUTPUT when running under Actions."""
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a") as fh:
            for k, v in kv.items():
                fh.write(f"{k}={v}\n")


def bump_changelog_text(text: str, stanza: dict, new: str) -> str:
    """Prepend a new `<src> (<new>-1) ...` stanza to a debian/changelog body.

    Reuses the existing distribution/urgency and the canonical Debian trailer
    (one space before `--`, two spaces before the RFC 2822 date).
    """
    date = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
    # Keep any epoch the maintainer set; upstream versions never carry one, and
    # dropping it would make the new Debian version sort older than the current.
    epoch = f"{stanza['epoch']}:" if stanza.get("epoch") else ""
    entry = (
        f"{stanza['source']} ({epoch}{new}-1) {stanza['distribution']}; urgency={stanza['urgency']}\n"
        f"\n"
        f"  * Update to upstream {new}.\n"
        f"\n"
        f" -- {CHANGELOG_AUTHOR}  {date}\n"
        f"\n"
    )
    return entry + text


def cmd_bump(pkg_name: str) -> int:
    pkg = next((p for p in PACKAGES if p["pkg"] == pkg_name), None)
    if not pkg or pkg["mode"] != "bump":
        print(f"refusing to bump {pkg_name!r}: not a configured bump package", file=sys.stderr)
        return 2

    stanza = current_stanza(pkg_name)
    current = stanza["version"] if stanza else None
    latest = latest_version(pkg["source"])
    if not (current and latest and is_outdated(pkg["source"], latest, current)):
        print(f"{pkg_name}: up to date ({current}, upstream {latest})")
        emit_outputs(bumped="false")
        return 0

    path = ROOT / "packages" / pkg_name / "debian" / "changelog"
    path.write_text(bump_changelog_text(path.read_text(), stanza, latest))
    print(f"{pkg_name}: {current} -> {latest}")
    print(f"  rewrote {path.relative_to(ROOT)}")
    emit_outputs(bumped="true", pn=pkg_name, old=current, new=latest)
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 1 and argv[0] == "check":
        return cmd_check()
    if len(argv) >= 2 and argv[0] == "bump":
        return cmd_bump(argv[1])
    print(__doc__)
    print("usage: version-check.py check | bump <package>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
