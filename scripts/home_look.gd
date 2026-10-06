extends RefCounted
## What a home should look like, as one small pure function the artist's tier and scaffold art plugs into (docs/art/requests.md,
## "Growth art"). Worked out from the home's own state, never stored, no costs or rules ride on it: it reads the building dict
## and nothing else. Static.

const Homes = preload("res://scripts/homes.gd")

## The sprite name each tier is drawn with (Art.building_sprite): all three borrow the Dwelling until Codex's tier art lands.
const SPRITES := ["dwelling", "dwelling", "dwelling"]
## While a scaffold stands, the sprite name of the overlay drawn over the home ("" until Codex draws one; the map then draws its
## own tint and beams).
const SCAFFOLD_SPRITE := ""


## {"tier": 0 to 2, "sprite": what to draw the home with, "site": "", "waiting" or "building", "scaffold": true while one
## stands, "fill": 0 to 1 (the materials delivered, 1 once all are in), "progress": 0 to 1 (how far the build is, 0 before it
## starts), "to": the tier it is becoming, or -1}.
static func state(b: Dictionary) -> Dictionary:
	var tier := Homes.tier_of(b)
	var site: String = b.get("site", "")
	return {
		"tier": tier,
		"sprite": SPRITES[tier],
		"site": site,
		"scaffold": site != "",
		"fill": Homes.fill(b) if site != "" else 0.0,
		"progress": clampf(float(b.get("site_t", 0.0)) / Homes.build_of(b), 0.0, 1.0) if site == "building" else 0.0,
		"to": tier + 1 if site != "" else -1,
	}
