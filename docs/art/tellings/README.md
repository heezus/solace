# The story of many tellings

Owner's 2026-10-27 art-only batch: 29 painted assets, five independent draft PRs into main. No `.gd`, tests, UI, overlays, gameplay or export changes. Claude reviews, wires the later groups and merges after green CI. No personal photographs, real-person likeness inputs or real-person names are included in this batch.

| Order | Assets | Review |
|---|---:|---|
| First telling ending and fireside | 4 | [#165](https://github.com/heezus/solace/pull/165) — `docs/art/tellings/first-ending/` |
| Three endings and next-run openings | 6 | [#166](https://github.com/heezus/solace/pull/166) — `docs/art/tellings/exits-openings/` |
| Kin, broken world and way out | 6 | [#167](https://github.com/heezus/solace/pull/167) — `docs/art/tellings/lore/` |
| Hearthkeeper, Sela and Bloom portraits | 3 | [#168](https://github.com/heezus/solace/pull/168) — `docs/art/tellings/portraits/` |
| New-run tiles and relic icons | 10 | [#170](https://github.com/heezus/solace/pull/170) — `docs/art/tellings/map-relics/` |

Each group directory lives on its own PR branch until merged. Its README explains display sizes and hooks; adjacent JSON records hold final prompts, reference roles, generated source basenames, measured dimensions, source hashes and regions where relevant. All images use built-in imagegen. Native player captures or size/alpha comparisons are included and inspected. They are review evidence; no UI redesign or new story wiring is supplied.

Stills retain original generated pixels: ten are 1586×992 and six are 1585×992. The one-pixel width variation is recorded exactly in each `spec.json`; no enlargement is presented as original detail. Portrait exports are exactly 1024×1280; unmodified 1122×1402 originals are retained beside the documented aspect-preserving export. Map sprites/icons retain their original transparent pixels, with explicit fitting regions and 1×1 footprints. Ruins and first wreck each have two variants; optional portrait expression variants are omitted.

Godot 4.7.2 imported all groups successfully. A post-import audit verifies source/hash/dimension/import pairs for all 29 assets and excludes production scripts/tests/settings from every diff. On the unchanged shared gameplay baseline `7518436`, local lint/format, strict editor warnings, full logic tests, main scene loading, scripted input play-through, long layout, menu/save/load and play-log passes all succeed. This local verification does not substitute for exact-head CI on the five PRs.

Skyward's story stills and the two way-out images are released by this brief. All UI, code-drawn overlays and other Skyreach buildings/era art remain held.
