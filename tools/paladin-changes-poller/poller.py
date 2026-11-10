#!/usr/bin/env python3
"""Tristan's Addon change poller.

Addons cannot go online from inside WoW. This script runs on your PC (e.g. from
a user systemd timer), polls the change feeds listed in research/data.json
(`change_sources`), keeps Paladin/PvP-relevant and Forever client/build items, and
writes them to the addon's Data/Changes.lua. Next /reload or login, the addon
shows them under "What's changed" with an unread badge.

    python3 tools/paladin-changes-poller/poller.py                      # write <repo>/Data/Changes.lua
    python3 tools/paladin-changes-poller/poller.py --output "<AddOns>/TristansAddon/Data/Changes.lua"
    python3 tools/paladin-changes-poller/poller.py --dry-run -v

Standard library only. No credentials, no logins: only public RSS/Atom/JSON/pages.
State (seen ids, page text baselines) lives in $XDG_STATE_HOME/tristans-addon/.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DATA_JSON = REPO / "research" / "data.json"
DEFAULT_OUTPUT = REPO / "Data" / "Changes.lua"
USER_AGENT = "TristansAddon-ChangePoller/0.1 (+https://github.com/ninepointlabs/tristans-addon)"
MAX_ITEMS = 200
TIMEOUT = 20

# Words that make an item Paladin/PvP-relevant. Talent/proc names are added from data.json.
PALADIN_WORDS = [
    "paladin", "retribution", "holy light", "flash of light", "holy shock", "holy strike", "judgement", "seal of",
    "blessing of", "greater blessing", "devotion aura", "retribution aura", "concentration aura", "righteous fury",
    "consecration", "exorcism", "hammer of justice", "hammer of wrath", "repentance", "divine shield", "divine protection",
    "lay on hands", "forbearance", "cleanse", "purify", "templar's bulwark", "holy shield", "unsealed wrath",
    "light's vigil", "oath of light", "divine favor", "sacred arbiter", "vengeance", "redemption",
    # PvP and battlegrounds (Tristan's Addon has a Battle section)
    "pvp", "battleground", "honor", "rank points", "warsong", "arathi basin", "alterac", "darkspear", "call to arms",
    "emboldened seal", "world pvp", "ruleset",
]
# Forever-wide items worth surfacing even without a Paladin keyword.
GENERAL_WORDS = ["hotfix", "class tuning", "patch notes", "known issues", "build"]
FOREVER_WORDS = ["forever", "wow forever", "camelot"]

ATOM = "{http://www.w3.org/2005/Atom}"


# ---------------------------------------------------------------- fetching ----
def fetch(url: str) -> tuple[str, str]:
    """Return (content_type, text)."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        ctype = resp.headers.get("Content-Type", "")
        raw = resp.read()
    return ctype, raw.decode("utf-8", errors="replace")


# ----------------------------------------------------------------- parsing ----
def strip_html(s: str) -> str:
    s = re.sub(r"(?is)<(script|style|noscript|svg)[^>]*>.*?</\1>", " ", s or "")
    s = re.sub(r"(?s)<br\s*/?>|</p>|</li>|</h\d>", "\n", s)
    s = re.sub(r"(?s)<[^>]+>", " ", s)
    s = html.unescape(s)
    return re.sub(r"[ \t\r\f\v]+", " ", s)


def text_lines(s: str) -> list[str]:
    return [ln.strip() for ln in strip_html(s).split("\n") if len(ln.strip()) > 25]


def parse_date(s: str | None) -> str:
    if not s:
        return dt.date.today().isoformat()
    s = s.strip()
    for fmt in ("%a, %d %b %Y %H:%M:%S %z", "%a, %d %b %Y %H:%M:%S %Z", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S.%f%z"):
        try:
            return dt.datetime.strptime(s.replace("Z", "+0000"), fmt).date().isoformat()
        except ValueError:
            continue
    m = re.match(r"(\d{4}-\d{2}-\d{2})", s)
    return m.group(1) if m else dt.date.today().isoformat()


def parse_feed(text: str) -> list[dict]:
    """RSS 2.0 or Atom -> [{title, link, date, body}]."""
    root = ET.fromstring(text)
    out = []
    if root.tag == ATOM + "feed":
        for e in root.findall(ATOM + "entry"):
            link = e.find(ATOM + "link")
            out.append({
                "title": (e.findtext(ATOM + "title") or "").strip(),
                "link": link.get("href") if link is not None else "",
                "date": parse_date(e.findtext(ATOM + "updated") or e.findtext(ATOM + "published")),
                "body": e.findtext(ATOM + "content") or e.findtext(ATOM + "summary") or "",
            })
        return out
    for it in root.iter("item"):
        cats = " ".join(c.text or "" for c in it.findall("category"))
        out.append({
            "title": (it.findtext("title") or "").strip(),
            "link": (it.findtext("link") or "").strip(),
            "date": parse_date(it.findtext("pubDate")),
            "body": (it.findtext("description") or "") + " " + cats,
        })
    return out


def parse_discourse(text: str) -> list[dict]:
    data = json.loads(text)
    title = data.get("title", "")
    slug, tid = data.get("slug", ""), data.get("id", "")
    out = []
    for p in data.get("post_stream", {}).get("posts", []):
        out.append({
            "title": f"{title} (post #{p.get('post_number')})",
            "link": f"https://us.forums.blizzard.com/en/wow/t/{slug}/{tid}/{p.get('post_number')}",
            "date": parse_date(p.get("updated_at") or p.get("created_at")),
            "body": p.get("cooked", ""),
        })
    return out


# --------------------------------------------------------------- relevance ----
def words_in(text: str, words: list[str]) -> list[str]:
    t = text.lower()
    return [w for w in words if re.search(r"(?<![a-z])" + re.escape(w) + r"(?![a-z])", t)]


def classify(entry: dict, source: dict, paladin_words: list[str]) -> tuple[bool, list[str], str]:
    """Return (keep, tags, summary)."""
    name = source["name"].lower()
    text = entry["title"] + "\n" + strip_html(entry["body"])
    if "wow-ui-source" in name:
        return True, ["client"], "Blizzard UI source changed on the forever branch (new client build?). Check `omaforge clients`."
    # Forever-only feeds have "forever" in the URL (Wowhead /rss/forever, the dev-notes
    # thread). The Blizzard blue tracker covers every game, so its items must say Forever.
    url = source["source_url"].lower()
    is_forever_feed = "forever" in url and "blizzard-tracker" not in url
    if not is_forever_feed and not words_in(text + " " + entry["link"], FOREVER_WORDS):
        return False, [], ""
    hits = words_in(text, paladin_words)
    if hits:
        lines = [ln for ln in text_lines(entry["body"]) if words_in(ln, paladin_words)]
        summary = " / ".join(lines[:3])[:400] if lines else ""
        return True, ["paladin"], summary
    if words_in(entry["title"], GENERAL_WORDS):
        return True, ["forever"], ""
    return False, [], ""


def item_id(source: str, link: str, title: str) -> str:
    return hashlib.sha1(f"{source}|{link}|{title}".encode()).hexdigest()[:12]


# ------------------------------------------------------------------- state ----
def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return Path(base) / "tristans-addon"


def load_state(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {"items": [], "pages": {}}


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=1))
    tmp.replace(path)


# ---------------------------------------------------------------- pipeline ----
def poll_source(source: dict, state: dict, paladin_words: list[str], fetcher, log) -> list[dict]:
    url, kind = source["source_url"], source.get("type", "")
    ctype, text = fetcher(url)
    label = short_source(source["name"])
    entries: list[dict] = []
    if kind.startswith("api") or url.endswith(".json"):
        entries = parse_discourse(text)
    elif kind.startswith(("rss", "atom")):
        try:
            entries = parse_feed(text)
        except ET.ParseError:
            log(f"  {label}: not XML ({ctype or 'unknown type'}); treating as a page")
            kind = "page"
    if kind == "page":
        return page_changes(source, label, text, state, paladin_words)
    if "wow-ui-source" in source["name"].lower():
        entries = entries[:5]  # one item per recent build commit is plenty
    out = []
    for e in entries:
        keep, tags, summary = classify(e, source, paladin_words)
        if keep:
            out.append({"id": item_id(label, e["link"], e["title"]), "date": e["date"], "source": label,
                        "title": e["title"][:200], "url": e["link"], "summary": summary, "tags": tags})
    return out


def page_changes(source: dict, label: str, text: str, state: dict, paladin_words: list[str]) -> list[dict]:
    """Diff visible text lines against the last run. First run only records a baseline."""
    url = source["source_url"]
    lines = sorted(set(text_lines(text)))
    digest = [hashlib.sha1(ln.encode()).hexdigest()[:16] for ln in lines]
    prev = state["pages"].get(url)
    state["pages"][url] = digest
    if prev is None:
        return []
    old = set(prev)
    new_lines = [ln for ln, h in zip(lines, digest) if h not in old]
    if not new_lines:
        return []
    is_hotfix = "hotfix" in source["name"].lower()
    relevant = [ln for ln in new_lines if words_in(ln, paladin_words)]
    if not relevant and not is_hotfix:
        return []
    shown = relevant or new_lines
    today = dt.date.today().isoformat()
    return [{"id": item_id(label, url, today + "|" + "|".join(shown[:3])), "date": today, "source": label,
             "title": f"{source['name']} updated" + (" (Paladin/PvP-related)" if relevant else ""), "url": url,
             "summary": " / ".join(shown[:3])[:400], "tags": ["paladin"] if relevant else ["forever"]}]


def short_source(name: str) -> str:
    n = name.lower()
    if "tracker" in n:
        return "Blizzard blue post"
    if "wowhead" in n:
        return "Wowhead"
    if "wow-ui-source" in n:
        return "Client build"
    if "icy veins" in n:
        return "Icy Veins"
    if "development notes" in n or "discourse" in n:
        return "Blizzard dev notes"
    if "hotfix" in n:
        return "Blizzard hotfixes"
    return "Blizzard"


def merge(existing: list[dict], new: list[dict]) -> tuple[list[dict], int]:
    # Same post can arrive via two feeds (thread RSS + thread JSON, blue tracker):
    # also dedupe on date + the start of the summary (or title when empty).
    def content_key(i):
        return (i["date"], (i.get("summary") or i["title"])[:80].lower())
    by_id = {i["id"]: i for i in existing}
    seen = {content_key(i) for i in existing}
    added = 0
    for i in new:
        if i["id"] not in by_id and content_key(i) not in seen:
            by_id[i["id"]] = i
            seen.add(content_key(i))
            added += 1
    items = sorted(by_id.values(), key=lambda i: (i["date"], i["id"]), reverse=True)[:MAX_ITEMS]
    return items, added


# ------------------------------------------------------------------ output ----
def lua_str(s: str) -> str:
    s = (s or "").replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", "")
    for k, v in {"\u2014": "-", "\u2013": "-", "\u2018": "'", "\u2019": "'", "\u201c": '"', "\u201d": '"', "\u2026": "..."}.items():
        s = s.replace(k, v)
    return f'"{s}"'


def render_lua(items: list[dict], generated: str) -> str:
    out = ["-- GENERATED by tools/paladin-changes-poller/poller.py. Do not edit by hand.",
           "local _, ns = ...", "ns.Data = ns.Data or {}", "ns.Data.Changes = {",
           f"  generated = {lua_str(generated)},", "  items = {"]
    for i in items:
        tags = ", ".join(lua_str(t) for t in i.get("tags", []))
        out.append("    { " + ", ".join([
            f"id = {lua_str(i['id'])}", f"date = {lua_str(i['date'])}", f"source = {lua_str(i['source'])}",
            f"title = {lua_str(i['title'])}", f"url = {lua_str(i['url'])}", f"summary = {lua_str(i.get('summary', ''))}",
            f"tags = {{ {tags} }}"]) + " },")
    out += ["  },", "}", ""]
    return "\n".join(out)


def write_atomic(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".changes-", suffix=".lua")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(body)
    os.replace(tmp, path)


def run(args, fetcher=fetch) -> int:
    log = (lambda m: print(m, file=sys.stderr)) if args.verbose else (lambda m: None)
    data = json.loads(Path(args.data).read_text(encoding="utf-8"))
    sources = data["change_sources"]
    paladin_words = PALADIN_WORDS + [str(t["name"]).split(" (")[0].lower() for t in data.get("talent_and_other_spell_ids", []) if t.get("name")]
    state_path = Path(args.state) if args.state else state_dir() / "poller.json"
    state = load_state(state_path)

    found, ok = [], 0
    for src in sources:
        if src.get("type") == "page" and "hub" in src["name"].lower():
            continue  # the Wowhead hub page is covered by its RSS feed and is mostly navigation noise
        try:
            items = poll_source(src, state, paladin_words, fetcher, log)
            ok += 1
            log(f"{short_source(src['name'])}: {len(items)} relevant item(s)")
            found += items
        except (urllib.error.URLError, OSError, ValueError, ET.ParseError) as e:
            print(f"warning: {src['name']}: {e}", file=sys.stderr)
    if ok == 0:
        print("error: every source failed; Changes.lua left unchanged", file=sys.stderr)
        return 2
    items, added = merge(state.get("items", []), found)
    state["items"] = items
    generated = dt.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    body = render_lua(items, generated)
    if args.dry_run:
        print(body)
    else:
        for out in args.output or [str(DEFAULT_OUTPUT)]:
            write_atomic(Path(out).expanduser(), body)
            log(f"wrote {out}")
        save_state(state_path, state)
    print(f"{added} new item(s), {len(items)} total, {ok}/{len(sources)} sources ok")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--output", action="append", help="Changes.lua path (repeatable). Default: <repo>/Data/Changes.lua")
    ap.add_argument("--data", default=str(DATA_JSON), help="research data.json with change_sources")
    ap.add_argument("--state", help="state file (default $XDG_STATE_HOME/tristans-addon/poller.json)")
    ap.add_argument("--dry-run", action="store_true", help="print the Lua instead of writing; don't save state")
    ap.add_argument("-v", "--verbose", action="store_true")
    return run(ap.parse_args(argv))


if __name__ == "__main__":
    sys.exit(main())
