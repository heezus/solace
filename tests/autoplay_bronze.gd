extends "res://tests/autoplay.gd"
## The headless player for the era after the stone age (stage 1 of Bronze Dawn). It plays the stone age exactly as
## Autoplay does, then keeps going after Bronze Dawn: it pushes roads east through the fog until the Copper Hills and
## the Tin Stream are in sight, researches toward Alloying, puts a Mine on the hills, a Smelter and a Crucible by the
## Hearth, digs ore by hand where that is quicker, and stops when the first Bronze is made.
## play_bronze() returns {"won", "seconds" (Bronze Dawn), "bronze_seconds" (the first Bronze, -1 for never),
## "minutes" (from Bronze Dawn to the first Bronze), "log"}.

const MINES := 1  # Mines on Copper Hills the bot builds (the Tin Stream is dug by hand: the Crucible takes one tin)
const COPPER_FIRST := 15  # Copper: Alloying costs 12, and a Crucible batch takes 3

var dawn_at := -1.0  # the clock when Bronze Dawn was won
var bronze_at := -1.0  # the clock when the first Bronze was made


func play_bronze(map_seed: int, max_seconds: float) -> Dictionary:
	var game := Sim.new()
	game.generate(map_seed)
	attach(game)
	while clock < max_seconds and not s.won:
		step(true)
	if s.won:
		dawn_at = clock
		goal_tech = "alloying"
		s.tech_tree.set_goal(goal_tech)
		lines.append("%5.0f s  == Bronze Dawn: the land opens ==" % clock)
		while clock < max_seconds and s.economy.inv.get("bronze", 0) == 0:
			step(true)
		if s.economy.inv.get("bronze", 0) > 0:
			bronze_at = clock
	var minutes := (bronze_at - dawn_at) / 60.0 if bronze_at >= 0.0 else -1.0
	return {"won": s.won, "seconds": dawn_at, "bronze_seconds": bronze_at, "minutes": minutes, "log": lines}


func _decide() -> void:
	if not s.won:
		super._decide()
		return
	_flood_reach()
	if _explore_ore() or _place_mine():
		return
	super._decide()


## The first Bronze needs the smelting chain to have run: copper for Alloying and for the batch, and one tin.
func _goal_wants(want: Dictionary) -> void:
	if not s.won:
		return
	if s.economy.inv.get("copper", 0) < COPPER_FIRST and not s.tech_tree.researched.has("alloying"):
		want["copper"] = want.get("copper", 0) + 12
	if s.tech_tree.researched.has("alloying") and s.economy.inv.get("bronze", 0) == 0:
		_want(want, Data.BUILDINGS["crucible"]["in"], 1)


## The era's workshops are due once their tech is in and the first Bronze still needs them.
func _workshops_due() -> Array:
	var out := super._workshops_due()
	if not s.won:
		return out
	if s.town.unlocked("smelter") and _count("smelter") == 0:
		out.append("smelter")
	if s.town.unlocked("crucible") and _count("crucible") == 0:
		out.append("crucible")
	return out


## Roads east through the fog toward the nearest ore not yet in sight: the copper first, then the tin. Where the river
## is in the way, a Wooden Bridge first.
func _explore_ore() -> bool:
	var copper := _ore_seen("copper_hills")
	if copper and _ore_seen("tin_stream"):
		return false
	var target := _hidden_ore("tin_stream" if copper else "copper_hills")
	if target.x < 0:
		return false
	if reach.has(target):
		return _explore_to(target)
	var step := _first_step_beyond_reach(target)
	if step.x < 0:
		return false
	if s.world.tile_at(step) == "river" and s.fog.is_revealed(step):
		return _bridge(step)
	return _explore_to(step)


## A Wooden Bridge on river tile p, if Paths & Haulers is in and it can be paid for.
func _bridge(p: Vector2i) -> bool:
	if not s.town.unlocked("bridge") or s.town.placement_error("bridge", p) != "":
		return false
	if not s.place("bridge", p):
		return false
	lines.append("%5.0f s    + Wooden Bridge at %s" % [clock, p])
	return true


## The first tile on the shortest way from where the Kith can walk to `target` that they cannot walk on (a river
## tile, the bank across it).
func _first_step_beyond_reach(target: Vector2i) -> Vector2i:
	var from := {}
	var todo: Array = []
	for p in reach:
		from[p] = p
		todo.append(p)
	while not todo.is_empty() and not from.has(target):
		var q: Vector2i = todo.pop_front()
		for n in World.NEIGHBORS:
			var r: Vector2i = q + n
			if s.world.in_bounds(r) and not from.has(r):
				from[r] = q
				todo.append(r)
	if not from.has(target):
		return Vector2i(-1, -1)
	var at := target
	while not reach.has(from[at]):
		at = from[at]
	return at


func _ore_seen(tile: String) -> bool:
	for y in s.world.height:
		for x in range(s.world.stone_width, s.world.width):
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == tile and s.fog.is_revealed(p):
				return true
	return false


## The nearest ore tile of its kind that is still under fog.
func _hidden_ore(tile: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in range(s.world.stone_width, s.world.width):
			var p := Vector2i(x, y)
			if s.world.tile_at(p) != tile or s.fog.is_revealed(p):
				continue
			var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
			if d < best_d:
				best = p
				best_d = d
	return best


## A Mine on the Copper Hills nearest the Hearth, once Mining is in.
func _place_mine() -> bool:
	if not s.town.unlocked("mine") or _count("mine") >= MINES:
		return false
	var hills := func(p):
		if s.world.tile_at(p) != "copper_hills":
			return -INF
		return -Vector2(p).distance_to(Vector2(s.world.camp_pos))
	return _place_best("mine", hills)
