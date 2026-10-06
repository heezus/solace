extends RefCounted
## Expeditions (design-system/16-starfall.md): an Expedition Post sends a party of two Kith into the fog and they walk home
## on their own. The target is the crash site (the Wreck) or the nearest fog; the pack (Light, Standard, Heavy) is taken from
## the stockpile as they leave, so with Keep sending on a repeat trip needs no clicking. The whole trip must fit in one day
## (Data.DAYLIGHT_SECONDS): a party that is late loses half its pack. At the Wreck a pack brings marks back for the Glyph
## Wall (Starfall.add_finds); in the far fog it brings a wide look instead. A party's state is in the Kith's own fields: job
## "expedition", phase "exp_out" or "exp_home", and `task` = {tile, target, pack, lead} (the lead resolves the trip), so it
## is saved with them. Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")
const Scouting = preload("res://scripts/scouting.gd")

const AUTO_SECONDS := 5.0  # how often a standing order looks for a chance to send


static func is_party(k: Dictionary) -> bool:
	return k["job"] == "expedition"


## How many Kith are out with a party.
static func count(s) -> int:
	var n := 0
	for k in s.people.kith:
		n += 1 if is_party(k) else 0
	return n


## True while an Expedition Post stands.
static func has_post(s) -> bool:
	for b in s.town.buildings:
		if b["type"] == "expedition_post":
			return true
	return false


## The tile a party walks to for `target`: the Wreck's (or dry ground next to it), or the nearest fog. (-1, -1) for none.
static func target_tile(s, target: String) -> Vector2i:
	if target == "wreck":
		return Scouting.goal(s, s.starfall.wreck) if s.starfall.wreck.x >= 0 else Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := INF
	var wet := Vector2i(-1, -1)
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.fog.is_revealed(p):
				continue
			if s.pathing.astar.is_point_solid(p):
				wet = p if wet.x < 0 else wet
				continue
			var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
			if d < best_d:
				best = p
				best_d = d
	return best if best.x >= 0 else (Scouting.goal(s, wet) if wet.x >= 0 else best)


## The unspent part of the cost: what the pack needs that the stockpile lacks, as "8 Berries and 4 Rope", "" when it is all there.
static func missing(s, pack: String) -> String:
	var parts: Array = []
	var cost: Dictionary = Data.PACKS[pack]["cost"]
	for id in cost:
		var short: int = cost[id] - int(s.economy.inv.get(id, 0))
		if short > 0:
			parts.append("%d %s" % [short, Data.ITEMS[id]["name"]])
	return " and ".join(parts)


## A pack's cost as words: "16 Berries, 4 Rope".
static func cost_text(pack: String) -> String:
	var parts: Array = []
	var cost: Dictionary = Data.PACKS[pack]["cost"]
	for id in cost:
		parts.append("%d %s" % [cost[id], Data.ITEMS[id]["name"]])
	return ", ".join(parts)


## What the Post's panel says about the trip now: {"ok": bool, "why": String (when not ok), "seconds": float, "late": bool}.
static func plan(s) -> Dictionary:
	var o: Dictionary = s.starfall.orders
	if not s.starfall.arrived() or not has_post(s):
		return {"ok": false, "why": Data.POST_NO_TARGET, "seconds": 0.0, "late": false}
	if o["target"] == "wreck" and s.starfall.wreck_found and not s.starfall.wreck_has_more():
		return {"ok": false, "why": Data.POST_NO_TARGET, "seconds": 0.0, "late": false}
	var to := target_tile(s, o["target"])
	if to.x < 0:
		return {
			"ok": false,
			"why": Data.POST_NO_FOG if o["target"] == "fog" else Data.POST_NO_WAY,
			"seconds": 0.0,
			"late": false
		}
	var secs: float = s.people.round_trip(s.world.camp_pos, to)
	if secs < 0.0:
		return {"ok": false, "why": Data.POST_NO_WAY, "seconds": 0.0, "late": false}
	var late := secs > Data.DAYLIGHT_SECONDS
	if count(s) >= Data.PARTY_SIZE * _posts(s):
		return {"ok": false, "why": Data.POST_OUT, "seconds": secs, "late": late}
	var lack := missing(s, o["pack"])
	if lack != "":
		return {"ok": false, "why": Data.POST_NEED % lack, "seconds": secs, "late": late}
	if _free(s).size() < Data.PARTY_SIZE:
		return {"ok": false, "why": Data.POST_NOBODY, "seconds": secs, "late": late}
	return {"ok": true, "why": "", "seconds": secs, "late": late}


## Send a party as the Post's orders say. Returns what to tell the player ("" never: it always says who went or why not).
static func send(s) -> String:
	var p := plan(s)
	if not p["ok"]:
		return p["why"]
	var o: Dictionary = s.starfall.orders
	var to := target_tile(s, o["target"])
	var who := _free(s).slice(0, Data.PARTY_SIZE)
	var names: Array = []
	for i in who.size():
		var k: Dictionary = s.people.kith[who[i]]
		s.people.drop_task(k)
		if not s.people.walk_to(k, to):
			return Data.POST_NO_WAY
		k["job"] = "expedition"
		k["phase"] = "exp_out"
		k["task"] = {"tile": to, "target": o["target"], "pack": o["pack"], "lead": i == 0}
		k["timer"] = 0.0
		k["cart"] = false
		names.append(k["name"])
	var cost: Dictionary = Data.PACKS[o["pack"]]["cost"]
	for id in cost:
		s.economy.inv[id] = int(s.economy.inv.get(id, 0)) - cost[id]
	return (
		Data.POST_SENT
		% [names[0], names[1], Data.TARGETS[o["target"]].to_lower(), Data.PACKS[o["pack"]]["name"].to_lower()]
	)


## One step for a party member `k`: walk out, look, walk home. The lead settles the trip at the Hearth.
static func tick(s, k: Dictionary, delta: float) -> void:
	k["timer"] += delta
	if not s.people.step(k, delta):
		return
	var task: Dictionary = k["task"]
	if k["phase"] == "exp_out":
		_arrive(s, k, task)
		k["phase"] = "exp_home"
		if s.people.walk_to(k, s.world.camp_pos):
			return
	if task["lead"]:
		_finish(s, k, task)
	_end(k)


## Check a standing order every AUTO_SECONDS: send a party when one can go.
static func auto(s, delta: float) -> void:
	var o: Dictionary = s.starfall.orders
	if not o["keep"] or not has_post(s):
		return
	s.starfall.post_clock += delta
	if s.starfall.post_clock < AUTO_SECONDS:
		return
	s.starfall.post_clock = 0.0
	if plan(s)["ok"]:
		s.events.append(send(s))


static func _arrive(s, k: Dictionary, task: Dictionary) -> void:
	if task["target"] == "wreck":
		s.fog.reveal(s.starfall.wreck, Data.WRECK_SIGHT)
		if task["lead"] and not s.starfall.wreck_found:
			s.starfall.wreck_found = true
			s.events.append(Data.WRECK_FOUND_LINE)
			s.story.record("wreck_found")
	else:
		s.fog.reveal(Kith.tile_of(k), Data.EXPEDITION_SIGHT)


static func _finish(s, k: Dictionary, task: Dictionary) -> void:
	var late: bool = k["timer"] > Data.DAYLIGHT_SECONDS
	if late:
		s.events.append(Data.LATE_LINE)
	if task["target"] == "wreck":
		var finds: int = Data.PACKS[task["pack"]]["finds"]
		if late:
			finds = ceili(finds / 2.0)
		var n: int = s.starfall.add_finds(finds)
		s.events.append(Data.WRECK_MARKS_LINE % n if n > 0 else Data.WRECK_NOTHING_LINE)
	else:
		s.events.append(Data.FOG_BACK_LINE % _compass(Vector2(task["tile"]) - Vector2(s.world.camp_pos)))


## "north", "south-east", ... for a step from the Hearth.
static func _compass(d: Vector2) -> String:
	var ns := "" if absf(d.y) < absf(d.x) * 0.4 else ("south" if d.y > 0.0 else "north")
	var ew := "" if absf(d.x) < absf(d.y) * 0.4 else ("east" if d.x > 0.0 else "west")
	return ns + ("-" if ns != "" and ew != "" else "") + ew


static func _end(k: Dictionary) -> void:
	k["job"] = ""
	k["phase"] = ""
	k["task"] = {}
	k["path"] = []


static func _posts(s) -> int:
	var n := 0
	for b in s.town.buildings:
		n += 1 if b["type"] == "expedition_post" else 0
	return n


## Indices of the Kith who may go (Scouting.available), nearest the Hearth first.
static func _free(s) -> Array:
	var out: Array = []
	for i in s.people.kith.size():
		if Scouting.available(s.people.kith[i]):
			out.append(i)
	out.sort_custom(
		func(a, b):
			var da := Vector2(Kith.tile_of(s.people.kith[a])).distance_to(Vector2(s.world.camp_pos))
			var db := Vector2(Kith.tile_of(s.people.kith[b])).distance_to(Vector2(s.world.camp_pos))
			return da < db
	)
	return out
