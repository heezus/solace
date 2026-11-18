extends RefCounted
## The Hearthfire (Step 9C-3): the surplus sink. Goods the stores would spill over their cap go into the Hearth's fire; each good counts for
## its worth, and every tier step of worth given in this telling lights a tier, +3% work speed each (five tiers, +15% at most). Growing the
## machine past the gate always pays. Always open and never required: it feeds itself (the Hearth card's switch turns that off), and it
## holds back exactly when Goal first does: a good the goal, the research queue or the next gate asks for is never drawn below what it asks,
## and Wood, Stone, Fiber and Clay keep a floor of 40. The state (worth given, the switch) lives in the Economy and is saved with it.
## Numbers: director/9c-numbers-draft.md. Pure functions of the game state.

const Data = preload("res://scripts/data.gd")
const GoalFirst = preload("res://scripts/goal_first.gd")
const FireTiers = preload("res://scripts/fire_tiers.gd")
const RateData = preload("res://scripts/rate_data.gd")

const SPILL := 0.9  # of its cap a good must stand at before the fire takes any of it
const KEEP_AT := 0.8  # of its cap the fire leaves a good standing at
const FLOOR := 40  # of a basic good the fire leaves
const BASIC := ["wood", "stone", "fiber", "clay"]
const NEVER := ["flint_tools", "bronze_tools", "iron_tools", "steel_tools"]  # what the Kin work with is never burnt
const WORTH := {
	"wood": 1.0,
	"stone": 1.0,
	"fiber": 1.0,
	"clay": 1.0,
	"grain": 1.0,
	"berries": 1.0,
	"charcoal": 1.0,
	"brick": 1.5,
	"fish": 2.0,
	"starfruit": 2.0,
	"flint": 2.0,
	"rope": 2.5,
	"flour": 2.5,
	"coal": 3.0,
	"copper_ore": 3.0,
	"tin": 3.0,
	"iron_ore": 3.0,
	"shard": 20.0,
	"copper": 9.0,
	"iron": 11.0,
	"wire": 11.0,
	"steel": 32.0,
	"bronze": 38.0,
	"shardwork": 53.0,
}
const BRIGHTER := "The Hearthfire burns brighter: tier %d, +%d%% work speed."


static func worth_of(good: String) -> float:
	return float(WORTH.get(good, 1.0))


## Worth given so far in this telling.
static func given(s) -> float:
	return float(s.economy.fire["worth"])


static func tier(s) -> int:
	return FireTiers.tier_of(given(s))


## The share the fire adds to work speed now (0 to 0.15).
static func bonus(s) -> float:
	return FireTiers.bonus_of(given(s))


## Worth still to give for the next tier (0 at the last tier).
static func to_next(s) -> float:
	var n := tier(s)
	return 0.0 if n >= FireTiers.TIERS.size() else float(FireTiers.TIERS[n]) - given(s)


## Of `good` the stores keep and the fire never takes: what the goal, the queue or the next gate asks for (`asked_goods`, from
## GoalFirst.asked), the gate's minutes of rate for a rated good, and the floor of a basic good.
static func keep(s, good: String, asked_goods: Dictionary) -> int:
	var out := 0
	if good in BASIC:
		out = FLOOR
	var ask := int(asked_goods.get(good, 0))
	if ask == GoalFirst.RATED:
		ask = RateData.keep(s.tech_tree.researched, good)
	return maxi(out, ask)


## How much of `good` the fire may take now: what is above what is kept, 0 for what the Kin work with.
static func spare(s, good: String, asked_goods: Dictionary) -> int:
	if good in NEVER:
		return 0
	return maxi(int(s.economy.inv.get(good, 0)) - keep(s, good, asked_goods), 0)


## Put `n` of `good` into the fire (at most what is spare). Returns the worth given; the tier-up is told over the Hearth.
static func give(s, good: String, n: int, asked_goods: Dictionary) -> float:
	var take := mini(n, spare(s, good, asked_goods))
	if take <= 0:
		return 0.0
	var before := tier(s)
	s.economy.pay({good: take}, "fire")
	var worth := worth_of(good) * float(take)
	s.economy.fire["worth"] = given(s) + worth
	var after := tier(s)
	if after > before:
		s.starfall.pops.append(BRIGHTER % [after, roundi(bonus(s) * 100.0)])
	return worth


## Once a game second (from Goal first's look, which has `asked_goods`): every good standing at SPILL of its cap loses what is above
## KEEP_AT of it to the fire, as far as it is spare. Does nothing when the switch is off.
static func feed(s, asked_goods: Dictionary) -> void:
	if not s.economy.fire["auto"]:
		return
	for good in Data.ITEM_ORDER:
		var cap: int = int(s.economy.caps.get(good, 0))
		var have: int = int(s.economy.inv.get(good, 0))
		if cap <= 0 or float(have) < SPILL * float(cap):
			continue
		give(s, good, have - roundi(KEEP_AT * float(cap)), asked_goods)


## "Hearthfire: tier 2 of 5, +6% work speed. 1,200 worth to the next." for the Hearth's card.
static func text(s) -> String:
	var n := tier(s)
	var out := "Hearthfire: tier %d of %d, +%d%% work speed." % [n, FireTiers.TIERS.size(), roundi(bonus(s) * 100.0)]
	if n < FireTiers.TIERS.size():
		out += " %d worth to the next." % roundi(to_next(s))
	return out
