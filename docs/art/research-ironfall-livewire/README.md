# Ironfall and Livewire research illustrations

All sixteen Ironfall and fourteen Livewire techs are covered by [exact source/region mappings](spec.json). [Ironfall native comparison](ironfall-native-review.png) and [Livewire native comparison](livewire-native-review.png) show the current placeholder at 24 px, proposed 24/34/48 px art and 96 px inspection. These are documentation composites, not runtime captures.

Twelve new exact-tech-stem transparent PNGs and generated Godot imports live under `art/rendered/research/`: `teardown`, `taught_hands_ii`, `iron_plough`, `bloom_sampling`, `livewire`, `tide_watch`, `foremen`, `powered_mines`, `firebreaks`, `chain_orders`, `living_ground`, `skyward`. Individual prompt records preserve built-in imagegen provenance; originals are unmodified. Rejected broad-background sources are not delivered.

## Shared-art design and native review

Follow [Art Direction](../../design-system/05-art-direction.md) and the existing `Art.research_sprite` shared map/item/research design. Eighteen slots reuse the relevant painted miniatures from #90–#92 and building PRs #135/#136, preserving material and silhouette consistency. All source dimensions, SHA-256 hashes, previous `icon` strings and suggested new mapping keys are in the manifest. The new tool and Bloom symbols use #137/#138's material/plant family as references, not as runtime dependencies.

Native review at the current 24 px card and 34 px default gate sizes found two issues and corrected them: research-specific head crops make Power Poles/Shard Lamps/Arc Lamps readable, and a dedicated bold leaf/root replaces sparse tide-decal reuse for Living Ground. Rail uses a short square rail/sleeper detail crop. The remaining buildings retain their measured source regions. Warm Kith timber/iron/brass, cool shard light, magenta/green Bloom and upper-left highlights stay coherent; no new palette, lore, scale or character identity is introduced. Taught Hands shows a guiding/learning gesture in the existing rust/cream clothing family.

## Claude hooks

The manifest is keyed by **tech ID**, not the repeated placeholder `icon` string. Give each tech its `suggested_icon` resolver key and use the supplied `[x,y,width,height]` region from its resource path with centered aspect-preserving fitting and `filter_clip`. Do not replace shared `watchtower`, `kiln`, `wanderer`, `kith` or `field` artwork globally. Merge the relevant map source groups #135/#136 before wiring their research references; already merged #90–#92 supply coal/iron terrain, Bloomery, Iron Tools and Steel.

These are research illustrations only. The Teardown bench symbol, plough, whistle, sample jar and emblems do not add map building/item slots or change mechanics. Skyward is a small wire/star **research emblem**; the held mast, end-card still and all Skyreach work remain excluded. No `.gd`, tests, UI, gameplay or map draw changes.

Godot 4.7.2 import, genuine-alpha checks, all 30 native comparisons and whitespace checks pass. Full CI is tracked on draft PR #139. Claude reviews/wires after green CI. Run `preview.py` with Pillow from the repository root to reproduce the manifest and boards; it reads dependency sources from the workspace, or their focused local Git branches before merge, without copying them into this PR.
