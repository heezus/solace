# Ironfall coal mine and bloomery

Two new exact-stem assets: `art/rendered/coal_mine.png` and `art/rendered/bloomery.png`, with generated imports. Transparent sculpted miniatures matching the existing industry atlas; 1×1 gameplay footprints. [Native 46 px / 96 px comparison](native-review.png), [exact regions and source hashes](spec.json), and built-in generation prompts are supplied.

Coal Mine: dark coal entrance, timber head frame, rope bucket and black spoil. Bloomery: exposed tapered clay stack, bellows, fire mouth and rough iron bloom. No railway/steam system is implied. The short smoke wisp is static art; continuous smoke/fire animation remains an engine layer if wanted.

## Claude hooks

Add each `spec.json` region to `Rendered.REGIONS`, keyed `coal_mine` / `bloomery`; set `SINGLE_BUILDINGS` to `["coal_mine",0]` and `["bloomery",0]`. Remove their `TINTS` stand-ins: color is already painted. Keep the existing building fit, 1×1 placement, coal-tile requirement, recipes, selection and save IDs unchanged.

Godot 4.7.2 import and the documentation-only comparison passed. Production drawing remains Claude's wiring; no game scripts or tests are edited here.
