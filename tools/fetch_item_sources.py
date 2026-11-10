#!/usr/bin/env python3
"""Fetch "where/how to get it" for every researched item from the Icy Veins Forever DB.

    python3 tools/fetch_item_sources.py            # writes research/item_sources.json

For each item in research/data.json (gear_by_bracket) this reads
https://db.icy-veins.com/wow-forever/items/<id> and keeps:
  - required level
  - Dropped By: boss/NPC name, NPC id, drop chance
  - Crafted With: profession, skill level, reagents
  - Reward From Quests: quest name + id (and whether it's a choice reward)
Then for each quest, https://db.icy-veins.com/wow-forever/quests/<id>:
  level, required level, faction, zone, start/end NPC and map coordinates.

The Icy Veins DB is marked "early access": anything it doesn't list is left
empty, never guessed. Polite: one request per second, generic User-Agent.
"""
from __future__ import annotations

import datetime as dt
import html
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "research" / "data.json"
OUT = ROOT / "research" / "item_sources.json"
ITEM_URL = "https://db.icy-veins.com/wow-forever/items/{}"
QUEST_URL = "https://db.icy-veins.com/wow-forever/quests/{}"
UA = "TristansAddon-DataBuild/0.1 (+https://github.com/ninepointlabs/tristans-addon)"
DELAY = 1.0
SECTIONS = {"Dropped By", "Crafted With", "Reward From Quests", "Sold By", "Contained In", "Same Appearance",
            "Patch History", "Used to Craft", "Item Effects", "Base Stats", "Requirements", "Weapon Stats"}


def fetch_lines(url: str) -> list[str]:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        s = r.read().decode("utf-8", errors="replace")
    s = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", s)
    s = html.unescape(re.sub(r"<[^>]+>", "\n", s))
    return [ln.strip() for ln in s.split("\n") if ln.strip()]


def section(lines: list[str], name: str) -> list[str]:
    if name not in lines:
        return []
    i = lines.index(name) + 1
    out = []
    while i < len(lines) and lines[i] not in SECTIONS and not lines[i].startswith("Spotted something"):
        out.append(lines[i])
        i += 1
    return out


def parse_item(lines: list[str]) -> dict:
    rec: dict = {}
    req = section(lines, "Requirements")
    if len(req) >= 2 and req[0] == "Level" and req[1].isdigit():
        rec["min_level"] = int(req[1])
    drops = []
    sec = section(lines, "Dropped By")
    if sec[:3] == ["NPC", "Chance", "Avg. Stack"]:
        rows = sec[3:]
        i = 0
        while i + 2 < len(rows) and rows[i + 1].startswith("#"):
            drops.append({"npc": rows[i], "npc_id": int(rows[i + 1][1:]),
                          "chance": rows[i + 2] if rows[i + 2].endswith("%") else None})
            i += 4 if i + 3 < len(rows) and rows[i + 3].replace(".", "").isdigit() else 3
    if drops:
        rec["drops"] = drops
    sold = []
    sec = section(lines, "Sold By")
    for i in range(len(sec) - 1):
        if sec[i + 1].startswith("#") and sec[i + 1][1:].isdigit() and not sec[i].startswith("#"):
            sold.append({"npc": sec[i], "npc_id": int(sec[i + 1][1:])})
    if sold:
        rec["sold_by"] = sold
    sec = section(lines, "Crafted With")
    if sec:
        craft = {"profession": sec[0]}
        if len(sec) > 1 and sec[1].isdigit():
            craft["skill"] = int(sec[1])
        if "Crafts:" in sec:
            j = sec.index("Crafts:") + 1
            while j < len(sec) and sec[j] in ("−", "+", "-"):  # quantity stepper
                j += 1
            reagents = []
            while j + 1 < len(sec) and sec[j].isdigit() and sec[j + 1] != "Craft time:":
                reagents.append({"count": int(sec[j]), "name": sec[j + 1]})
                j += 2
            if reagents:
                craft["reagents"] = reagents
        rec["crafted"] = craft
    quests = []
    sec = section(lines, "Reward From Quests")
    choice = False
    for i, ln in enumerate(sec):
        if ln == "Choice":
            choice = True
            continue
        if i + 1 < len(sec) and sec[i + 1].startswith("#") and sec[i + 1][1:].isdigit() and not ln.startswith("#"):
            quests.append({"name": ln, "quest_id": int(sec[i + 1][1:]), "choice": choice})
            choice = False
    if quests:
        rec["quests"] = quests
    return rec


COORD = re.compile(r"^(\d{1,2}(?:\.\d)?), (\d{1,2}(?:\.\d)?)$")


def parse_quest(lines: list[str]) -> dict:
    q: dict = {}
    for ln in lines:
        for key, pat, conv in (("level", r"^Level: (\d+)$", int), ("min_level", r"^Requires level (\d+)$", int),
                               ("faction", r"^Faction: (.+)$", str), ("zone", r"^Zone: (.+)$", str),
                               ("start_npc", r"^Start: (.+)$", str), ("end_npc", r"^End: (.+)$", str)):
            m = re.match(pat, ln)
            if m and key not in q:
                q[key] = conv(m.group(1))
    # Map block: "Map", <zone>, "<label>", "<x, y>", ...
    if "Map" in lines:
        i = lines.index("Map") + 1
        zone = None
        pins = []
        while i < len(lines) and lines[i] not in ("Quest Text", "Description", "Rewards", "Patch History"):
            ln = lines[i]
            m = COORD.match(ln)
            if m and i > 0 and pins is not None:
                label = lines[i - 1]
                if not COORD.match(label):
                    pins.append({"zone": zone, "label": label, "x": float(m.group(1)), "y": float(m.group(2))})
            elif ln != "Click to copy" and i + 1 < len(lines) and not COORD.match(lines[i + 1]) and not ln.startswith(("Start", "End")):
                zone = ln
            i += 1
        # de-duplicate (labels repeat after the coordinates)
        seen, uniq = set(), []
        for p in pins:
            k = (p["zone"], p["label"], p["x"], p["y"])
            if k not in seen:
                seen.add(k)
                uniq.append(p)
        if uniq:
            q["pins"] = uniq
    return q


def main() -> int:
    # Optional argument: another data file with gear_by_bracket (default research/data.json).
    data_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DATA
    data = json.loads(data_path.read_text(encoding="utf-8"))
    ids = []
    for g in data["gear_by_bracket"]:
        ids.append(g["item_id"])
    for w in data.get("wands", []):
        ids.append(w["item_id"])
    for q in data.get("quests", []):
        if q.get("reward_item_id"):
            ids.append(q["reward_item_id"])
    ids = list(dict.fromkeys(ids))
    today = dt.date.today().isoformat()
    items, quests, errors = {}, {}, []
    for n, item_id in enumerate(ids, 1):
        url = ITEM_URL.format(item_id)
        try:
            rec = parse_item(fetch_lines(url))
        except (urllib.error.URLError, OSError) as e:
            errors.append(f"item {item_id}: {e}")
            continue
        finally:
            time.sleep(DELAY)
        rec.update({"source_url": url, "checked": today})
        items[str(item_id)] = rec
        for q in rec.get("quests", []):
            quests.setdefault(q["quest_id"], None)
        print(f"[{n}/{len(ids)}] {item_id}: " + ", ".join(k for k in ("drops", "crafted", "quests", "sold_by") if k in rec), file=sys.stderr)
    for qid in list(quests):
        url = QUEST_URL.format(qid)
        try:
            q = parse_quest(fetch_lines(url))
        except (urllib.error.URLError, OSError) as e:
            errors.append(f"quest {qid}: {e}")
            continue
        finally:
            time.sleep(DELAY)
        q.update({"source_url": url, "checked": today})
        quests[qid] = q
    out = {"items": items, "quests": {str(k): v for k, v in quests.items() if v},
           "source": "https://db.icy-veins.com/wow-forever/ (early access)", "checked": today, "errors": errors}
    OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    covered = sum(1 for r in items.values() if any(k in r for k in ("drops", "crafted", "quests", "sold_by")))
    print(f"wrote {OUT.relative_to(ROOT)}: {len(items)} items ({covered} with a source), {len(out['quests'])} quests, {len(errors)} errors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
