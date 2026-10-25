#!/usr/bin/env python3
"""Turn the baseline rows of a folder (seed_<map>.json, written by tests/tools/pace.gd `baseline`) into the supply and use ledger
tables of Step 6: ledger_<era>.md and ledger_<era>.json, one section per seed.

    python3 tests/tools/ledger_md.py <folder of seed_*.json> [out folder]

Each row's "ledger" comes from tests/tools/ledger.gd. Nothing here is a balance number: it only lays the measured rows out."""
import glob
import json
import os
import re
import sys

ERAS = ["stone_age", "bronze_dawn", "starfall", "ironfall", "livewire"]
TOP = 3  # sources shown per good, by amount


def top(by, n=TOP):
    items = sorted(by.items(), key=lambda kv: -kv[1])
    shown = ", ".join("%s %.2f" % (k, v) for k, v in items[:n])
    more = len(items) - n
    return shown + (" (+%d)" % more if more > 0 else "") if shown else "-"


def goods_table(ledger):
    lines = [
        "| good | made a min | used a min | cost: build / research / other (refunded) | released | stock start / mid / end | cap | min at cap | min at 0 waiting | change (stores + buffers) vs flows |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    goods = ledger["goods"]
    for gid in sorted(goods, key=lambda k: -(sum(goods[k]["made_per_min"].values()) + sum(goods[k]["used_per_min"].values()))):
        g = goods[gid]
        lines.append(
            "| %s | %s | %s | %d / %d / %d (+%d) | %d | %d / %d / %d | %d | %.1f | %.1f | %+d vs %+.0f |"
            % (
                gid,
                top(g["made_per_min"]),
                top(g["used_per_min"]),
                g["paid_build"],
                g["paid_research"],
                g.get("paid_other", 0),
                g["refunded"],
                g["released"],
                g["stock"][0],
                g["stock"][1],
                g["stock"][2],
                g["cap"],
                g["cap_min"],
                g["zero_min"],
                g["change"],
                g["flow_change"],
            )
        )
    return lines


def kith_table(ledger):
    lines = [
        "| minute | Kith | homes | jobs | filled | haulers wanted | haulers standing | idle | food made a min | food eaten a min |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for k in ledger["kith"]:
        lines.append(
            "| %.1f | %d | %d | %d | %d | %d | %d | %d | %.1f | %.1f |"
            % (
                k["minute"],
                k["kith"],
                k["homes"],
                k["jobs"],
                k["jobs_filled"],
                k["haulers_wanted"],
                k["haulers_standing"],
                k["idle"],
                k["food_made_per_min"],
                k["food_eaten_per_min"],
            )
        )
    return lines


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else src
    os.makedirs(out, exist_ok=True)
    by_era = {e: {} for e in ERAS}
    for path in sorted(glob.glob(os.path.join(src, "seed_*.json"))):
        seed = int(re.search(r"seed_(\d+)\.json", path).group(1))
        rows = json.load(open(path))
        rows = rows["eras"] if isinstance(rows, dict) else rows
        for row in rows:
            if "ledger" in row:
                by_era[row["era"]][seed] = row
    for era, seeds in by_era.items():
        if not seeds:
            continue
        md = ["# Ledger: %s" % era.replace("_", " "), ""]
        flagged = []
        for seed in sorted(seeds):
            row = seeds[seed]
            ledger = row["ledger"]
            for f in ledger["flags"]:
                flagged.append("seed %d: %s" % (seed, f))
        md += ["## Flags", ""] + (["- " + f for f in flagged] if flagged else ["None."]) + [""]
        for seed in sorted(seeds):
            row = seeds[seed]
            ledger = row["ledger"]
            check = ledger["check"]
            md += [
                "## Seed %d" % seed,
                "",
                "%.1f min, ended %s, goals %d of %d. Kith at the end %d. Coal in the ground %d (%d seams)."
                % (
                    ledger["length_min"],
                    row.get("ended"),
                    row.get("goals_done", 0),
                    row.get("goals_total", 0),
                    row["end"]["kith"],
                    ledger["finite"]["coal_in_ground"],
                    ledger["finite"]["seams"],
                ),
                "Goods sum: stores and buffers changed by %+d, flows say %+.0f, off by %.1f%% of the flow, %.1f%% of the change (bar 2%% of the flow): %s."
                % (
                    check["change"],
                    check["flow_change"],
                    100.0 * check["off_share"],
                    100.0 * check["off_share_of_change"],
                    "met" if check["met"] else "NOT met",
                ),
                "",
            ]
            md += goods_table(ledger) + [""] + kith_table(ledger) + [""]
        open(os.path.join(out, "ledger_%s.md" % era), "w").write("\n".join(md))
        json.dump({str(s): r["ledger"] for s, r in seeds.items()}, open(os.path.join(out, "ledger_%s.json" % era), "w"), indent=1)
        print("wrote ledger_%s.md (seeds %s)" % (era, sorted(seeds)))


if __name__ == "__main__":
    main()
