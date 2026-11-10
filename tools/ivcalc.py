#!/usr/bin/env python3
"""Decode WoW Forever Paladin talent-build links (Icy Veins and Wowhead). Stdlib only.

Icy Veins links look like
    https://www.icy-veins.com/wow-forever/paladin-talent-calculator#tc-CCCBBBBB...~70755-d1899b7d

Encoding (from the calculator bundle, archived as
research/raw/iv_forever_talent_calculator_js_b94ba8132c852960488634adf9ed4141.js,
`extractInvestedPoints` / `getTalentByUrlId` / `updateUrl`):
  * the fragment is `#tc-` + one character per talent point, in the order the points
    were spent, + `~<calculator data version>` (e.g. `70755-d1899b7d`);
  * each character is a talent's `urlId`, a fixed per-talent field in the calculator
    data (static.icy-veins.com/r2/icydb/wowf/talents/<version>/paladin.json, archived as
    research/raw/ivcalc_talents_<version>_paladin.json). The ids are NOT positional
    (they are not positional), so they must come from the data
    of the link's version;
  * a talent's rank is the number of times its character appears; unknown characters
    are ignored by the calculator.

Wowhead `/talent-calc/paladin/...` links use one digit per talent in tree order, trees
separated by `-` (same scheme as decode_build in tools/build_data.py).

decode() maps the link's talents onto the target (current) trees by name and checks
max ranks, row requirements (`required_points` = points in earlier rows of the same
tree) and the 51-point cap.

    python3 tools/ivcalc.py          # decode every build in research/parts/core.json
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAX_POINTS = 51
COLUMNS = 4

IV_RE = re.compile(r"#tc-([^~#?&\s]*)(?:~(\d+-[0-9a-f]+))?")
WH_RE = re.compile(r"/talent-calc/paladin/(?:v(?:[a-z]+|\d))?([0-9-]*)")


def normalize_trees(data) -> list[dict]:
    """Accept raw Icy Veins calculator JSON ({talentGroups: ...}), the
    tools/fetch_talents.py format ({trees: ...}) or a bare list of trees, and return
    [{name, talents: [{name, row, max_rank, required_points, url_id?}]}]."""
    if isinstance(data, dict) and "talentGroups" in data:
        trees = []
        for g in data["talentGroups"]:
            talents = []
            for i, t in enumerate(g["talents"]):
                if not t:
                    continue
                talents.append({
                    "name": t["name"],
                    "row": i // COLUMNS + 1,
                    "col": i % COLUMNS + 1,
                    "max_rank": t["maxRank"],
                    "required_points": t["requiredPoints"],
                    "url_id": t.get("urlId"),
                })
            trees.append({"name": g["name"], "talents": talents})
        return trees
    if isinstance(data, dict) and "trees" in data:
        return data["trees"]
    return data


def load_trees(path) -> list[dict]:
    return normalize_trees(json.loads(Path(path).read_text(encoding="utf-8")))


def _validate(target_trees: list[dict], points_by_name: dict[str, int]) -> dict:
    known = {t["name"] for tree in target_trees for t in tree["talents"]}
    missing = [n for n, p in points_by_name.items() if p and n not in known]
    if missing:
        return {"valid": False, "reason": "talent(s) not in current trees: " + ", ".join(sorted(missing))}
    out_trees, total = [], 0
    for tree in target_trees:
        talents = tree["talents"]
        pts = [points_by_name.get(t["name"], 0) for t in talents]
        for t, p in zip(talents, pts):
            if p > t["max_rank"]:
                return {"valid": False, "reason": f"{t['name']}: {p} points but max rank is {t['max_rank']} (tree changed?)"}
            above = sum(pp for tt, pp in zip(talents, pts) if tt["row"] < t["row"])
            if p and above < t["required_points"]:
                return {"valid": False, "reason": f"{t['name']} needs {t['required_points']} points above it ({above} spent)"}
        spent = sum(pts)
        total += spent
        out_trees.append({"points": pts, "spent": spent})
    if total > MAX_POINTS:
        return {"valid": False, "reason": f"{total} points (max {MAX_POINTS} at level 60)"}
    return {"valid": True, "total": total, "level": total + 9, "trees": out_trees}


def _decode_iv(fragment: str, version: str | None, trees_by_version: dict, target_trees: list[dict]) -> dict:
    if not version:
        return {"valid": False, "reason": "Icy Veins link has no ~<version> suffix"}
    if version not in trees_by_version:
        return {"valid": False, "reason": f"no calculator data for version {version}"}
    by_id = {}
    for tree in normalize_trees(trees_by_version[version]):
        for t in tree["talents"]:
            if t.get("url_id") is None:
                return {"valid": False, "reason": f"version {version} data has no url ids (re-run tools/fetch_talents.py)"}
            by_id[str(t["url_id"])] = t["name"]
    points: dict[str, int] = {}
    unknown = sorted({c for c in fragment if c not in by_id})
    if unknown:
        return {"valid": False, "reason": "unknown talent id(s) " + "".join(unknown) + f" for version {version}"}
    for c in fragment:
        points[by_id[c]] = points.get(by_id[c], 0) + 1
    return _validate(target_trees, points)


def _decode_wh(digits: str, target_trees: list[dict]) -> dict:
    parts = digits.split("-")
    if len(parts) > len(target_trees):
        return {"valid": False, "reason": "more trees than the class has"}
    parts += [""] * (len(target_trees) - len(parts))
    points: dict[str, int] = {}
    for tree, ds in zip(target_trees, parts):
        if len(ds) > len(tree["talents"]):
            return {"valid": False, "reason": f"{tree['name']}: more talents than the tree has"}
        for t, c in zip(tree["talents"], ds):
            if int(c):
                points[t["name"]] = int(c)
    return _validate(target_trees, points)


def decode(url: str, trees_by_version: dict[str, list[dict]], target_trees: list[dict]) -> dict:
    """Decode a build link into per-talent points for `target_trees` (same shape as
    decode_build in tools/build_data.py)."""
    url = url or ""
    target_trees = normalize_trees(target_trees)
    if "icy-veins.com" in url and "talent-calculator" in url:
        m = IV_RE.search(url)
        if not m:
            return {"valid": False, "reason": "Icy Veins calculator link without a #tc- build"}
        return _decode_iv(m.group(1), m.group(2), trees_by_version, target_trees)
    if "wowhead.com" in url:
        if not re.search(r"wowhead\.com/forever/", url):
            return {"valid": False, "reason": "not a Wowhead Forever talent-calc link"}
        m = WH_RE.search(url)
        if not m or not m.group(1).strip("-"):
            return {"valid": False, "reason": "Wowhead talent-calc link without a build"}
        return _decode_wh(m.group(1), target_trees)
    return {"valid": False, "reason": "not an Icy Veins or Wowhead talent-calc build link"}


def default_trees_by_version(root: Path = ROOT) -> dict[str, list[dict]]:
    """Committed tree files research/talents_paladin*.json (tools/fetch_talents.py keeps url_id)."""
    out = {}
    for p in sorted((root / "research").glob("talents_paladin*.json")):
        d = json.loads(p.read_text(encoding="utf-8"))
        out[d["version"]] = d["trees"]
    return out


def main() -> int:
    core = json.loads((ROOT / "research" / "data.json").read_text(encoding="utf-8"))
    target = load_trees(ROOT / "research" / "talents_paladin.json")
    tbv = default_trees_by_version()
    bad = 0
    for b in core.get("builds", []):
        r = decode(b["talent_calc_url"], tbv, target)
        line = f"{b['spec']:<10} {b['purpose']:<22} valid={r['valid']}"
        if r["valid"]:
            spent = "/".join(str(t["spent"]) for t in r["trees"])
            line += f" total={r['total']} ({spent})"
            if r["total"] != MAX_POINTS:
                line += f" NOTE: not {MAX_POINTS} points (level {r['level']} build)"
                if "60" in b.get("purpose", "") or "Raid" in b.get("purpose", "") or "Dungeon" in b.get("purpose", ""):
                    line += " -> show as link-only"
                    bad += 1
        else:
            line += f" reason={r['reason']}"
            bad += 1
        print(line)
    print(f"{len(core.get('builds', []))} builds, {bad} need attention")
    return 0


if __name__ == "__main__":
    sys.exit(main())
