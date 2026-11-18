extends RefCounted
## The Hearthfire's tiers (scripts/hearthfire.gd): how much worth lights each, and the work speed each adds. Apart from hearthfire.gd so
## that scripts/bonuses.gd can read it without a loop.

const TIERS := [600, 1500, 3000, 5000, 8000]  # worth given in all to light tier 1 to 5
const SPEED := 0.03  # work speed each tier adds


## The tier lit by `worth` given (0 to 5).
static func tier_of(worth: float) -> int:
	var n := 0
	for need in TIERS:
		if worth >= float(need):
			n += 1
	return n


## The share of work speed `worth` given adds (0 to 0.15).
static func bonus_of(worth: float) -> float:
	return SPEED * float(tier_of(worth))
