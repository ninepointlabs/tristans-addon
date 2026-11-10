#!/usr/bin/env python3
"""Fetch the Paladin talent trees for WoW Forever from Icy Veins' talent-calculator data.

    python3 tools/fetch_talents.py                     # latest version -> research/talents_paladin.json
    python3 tools/fetch_talents.py <version> <out.json> # a specific calculator version

Source: the JSON behind https://www.icy-veins.com/wow-forever/talent-calculator
(static.icy-veins.com/r2/icydb/wowf/talents/<version>/paladin.json). Each version is
tied to a client build (e.g. 70862). Wowhead's talent-calc pages are blocked for
scripts (HTTP 403), so their build strings are decoded against this layout in
tools/build_data.py, and each decode is validated (max ranks, row requirements,
total points) before the addon shows it.

Stores names, grid positions, max ranks, required points, icon file ids, rank
spell ids and the plain-text description of the first and last rank.
"""
from __future__ import annotations

import datetime as dt
import html
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "research" / "talents_paladin.json"
BASE = "https://static.icy-veins.com/r2/icydb/wowf/talents"
PAGE = "https://www.icy-veins.com/wow-forever/paladin-talent-calculator"
UA = "TristansAddon-DataBuild/0.1 (+https://github.com/ninepointlabs/tristans-addon)"
COLUMNS = 4  # the calculator lays each tree out as an 11 x 4 grid


def get_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def desc(tooltip: str) -> str:
    m = re.search(r'<div class="icy-tt-desc">(.*?)</div>', tooltip or "", re.S)
    text = re.sub(r"<[^>]+>", " ", m.group(1) if m else "")
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def main() -> int:
    # Optional: a specific calculator version (e.g. 70755-d1899b7d, used by older
    # Icy Veins build links) and an output path.
    index = get_json(f"{BASE}/index.json")
    version = sys.argv[1] if len(sys.argv) > 1 else index["latest"]
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    build = next((v.get("build") for v in index.get("versions", []) if v.get("version") == version), None)
    url = f"{BASE}/{version}/paladin.json"
    raw = get_json(url)
    trees = []
    for g in raw["talentGroups"]:
        talents = []
        for i, t in enumerate(g["talents"]):
            if not t:
                continue
            ranks = t.get("ranks") or []
            talents.append({
                "name": t["name"],
                "row": i // COLUMNS + 1,
                "col": i % COLUMNS + 1,
                "max_rank": t["maxRank"],
                "required_points": t["requiredPoints"],
                "icon": t.get("icon"),
                "node_id": t.get("nodeId"),
                "url_id": t.get("urlId"),  # Icy Veins build links encode talents by this id
                "rank_spell_ids": [r["id"] for r in ranks],
                "desc_rank1": desc(ranks[0]["tooltip"]) if ranks else "",
                "desc_max": desc(ranks[-1]["tooltip"]) if ranks else "",
                "change": t.get("change", ""),
            })
        trees.append({"name": g["name"], "talents": talents})
    out = {
        "class": "Paladin",
        "version": version,
        "client_build": build,
        "trees": trees,
        "source_url": url,
        "page_url": PAGE,
        "checked": dt.date.today().isoformat(),
    }
    out_path.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {out_path}: version {version} (build {build}), "
          + ", ".join(f"{t['name']} {len(t['talents'])}" for t in trees))
    return 0


if __name__ == "__main__":
    sys.exit(main())
