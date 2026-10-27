extends RefCounted
## What the headless players do about relics (scripts/relics.gd, Step 7E): in a Cataclysm run, once haulers are known, the bot lays a road
## from the road network to each ruin that holds the Old Lantern or the Founders' Cart, and sends a Kith to dig it out. It leaves the
## Everburning Forge where it lies: the bot raises its Forge in its own yard, beside the Boiler it powers, and a relic Forge stands where
## the old town's heaviest building stood. All static, over the bot.

const AutoplayBlueprints = preload("res://tests/autoplay_blueprints.gd")
const Relics = preload("res://scripts/relics.gd")
const Scouting = preload("res://scripts/scouting.gd")
const Ui = preload("res://scripts/ui.gd")

const WANTED := ["lantern", "cart"]
const ROADS_PER_DECISION := 4
const RETRY := 30  # decisions to leave a ruin alone after a road to it could not be laid (the search is the dear part)

## Relic id -> decisions left before the bot tries its road again.
static var _rest := {}


## What the bot does about what an ending handed on: lay a kept blueprint when it can pay for it, or work toward a relic. True when
## the decision was spent.
static func carried(bot) -> bool:
	return AutoplayBlueprints.lay_ready(bot) or dig(bot)


## One step toward the next relic worth digging, true when it was spent (a road laid, or a crew sent). Nothing in a run with no ruins.
static func dig(bot) -> bool:
	var s = bot.s
	if s.carry.ruins.is_empty() or not s.tech_tree.researched.has("haulers"):
		return false
	for r in Relics.waiting(s):
		var id: String = r["def"]["id"]
		if id not in WANTED or not s.fog.is_revealed(r["pos"]) or not Relics.digging(s, id).is_empty():
			continue
		if _rest.get(id, 0) > 0:
			_rest[id] -= 1
			continue
		if Relics.roads_beside(s, r["pos"]).is_empty():
			if _road(bot, r["pos"]):
				return true
			_rest[id] = RETRY
		elif Ui.idle_kith(s) > 0:
			Scouting.dig(s, r["pos"])
			if not Relics.digging(s, id).is_empty():
				return true
	return false


## Lay the first tiles of the road from the ruin at `p` to the network, true when any went down.
static func _road(bot, p: Vector2i) -> bool:
	var laid := 0
	for q in bot._road_path(p):
		if laid >= ROADS_PER_DECISION or not bot._road_affordable(q):
			break
		if bot.s.place("road", q):
			laid += 1
	return laid > 0
