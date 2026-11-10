#!/usr/bin/env python3
"""Merge research/parts/core.json + research/parts/gear.json into research/data.json."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
core = json.loads((HERE / "parts" / "core.json").read_text(encoding="utf-8"))
gear = json.loads((HERE / "parts" / "gear.json").read_text(encoding="utf-8"))
out = dict(core)
for k, v in gear.items():
    if k in ("gaps", "conflicts") and k in out:
        out[k] = list(out[k]) + list(v)
    elif k == "sources" and k in out:
        out[k] = {**out[k], **v}
    elif k in out:
        raise SystemExit(f"merge: key {k!r} in both parts")
    else:
        out[k] = v
(HERE / "data.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
print("wrote research/data.json:", ", ".join(f"{k}={len(v) if hasattr(v, '__len__') else v}" for k, v in out.items()))
