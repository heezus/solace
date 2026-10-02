extends "res://tests/autoplay.gd"
## The headless player for the era after the stone age (Bronze Dawn). It plays the stone age exactly as Autoplay does,
## then keeps going after Bronze Dawn: it pushes roads east through the fog until the Copper Hills and the Tin Stream
## are in sight, researches toward Alloying, puts a Mine on the hills, a Smelter and a Crucible by the Hearth, digs ore
## by hand where that is quicker, and stops when the first Bronze is made (play_bronze), or plays on (play_to_star):
## the research goal becomes The Falling Star, and it adds Mines on the hills and the Tin Stream, a Cart Shed and a
## Watchtower, until the era ends.
## play_bronze() returns {"won", "seconds" (Bronze Dawn), "bronze_seconds" (the first Bronze, -1 for never),
## "minutes" (from Bronze Dawn to the first Bronze), "log"}; play_to_star() adds "star_seconds" (-1 for never) and
## "star_minutes" (from the first Bronze to The Falling Star, -1 for never).

const MINES := 1  # Mines on Copper Hills the bot builds before the first Bronze (the Tin Stream is dug by hand)
const MINES_COPPER := 4  # ...and the most it builds on the hills once it plays on
const MINES_TIN := 1  # Mines on the Tin Stream after the first Bronze
const STAR_WORKSHOPS := {"smelter": 3, "crucible": 2}  # after the first Bronze: the later techs cost lots of both
const MINE_ORE := 120.0  # one more copper Mine for every this much Copper Ore still short
const COPPER_FIRST := 15  # Copper: Alloying costs 12, and a Crucible batch takes 3

## Called once with the bot when Bronze Dawn is won, before the bot plays on: the state is then the stone age's last.
var on_dawn: Callable
## Called once with the bot at the moment of the first Bronze (play_to_star calls it and plays on).
var on_bronze: Callable
var dawn_at := -1.0  # the clock when Bronze Dawn was won
var bronze_at := -1.0  # the clock when the first Bronze was made
var star_at := -1.0  # the clock when The Falling Star was researched


func play_bronze(map_seed: int, max_seconds: float) -> Dictionary:
	var game := Sim.new()
	game.generate(map_seed)
	attach(game)
	while clock < max_seconds and not s.won:
		step(true)
	return _after_dawn(max_seconds)


## Play the whole era: Bronze Dawn, the first Bronze, then on until The Falling Star (or `max_seconds`).
func play_to_star(map_seed: int, max_seconds: float) -> Dictionary:
	var game := Sim.new()
	game.generate(map_seed)
	attach(game)
	while clock < max_seconds and not s.won:
		step(true)
	var r := _after_dawn(max_seconds)
	if bronze_at >= 0.0:
		while clock < max_seconds and not fell():
			step(true)
	r["star_seconds"] = star_at
	r["star_minutes"] = star_minutes()
	return r


## Minutes from the first Bronze to the Falling Star, -1 when either has not happened.
func star_minutes() -> float:
	return (star_at - bronze_at) / 60.0 if star_at >= 0.0 and bronze_at >= 0.0 else -1.0


## True once The Falling Star is researched: the era has ended (and when, in `star_at`).
func fell() -> bool:
	if star_at < 0.0 and "star_falling" in s.story.events:
		star_at = clock
		lines.append("%5.0f s  == The Falling Star: the era ends ==" % clock)
	return star_at >= 0.0


## Play on from a game that has just won Bronze Dawn (a run restored from a save made then), `at` seconds in.
func play_from_dawn(game: Sim, at: float, max_seconds: float) -> Dictionary:
	attach(game)
	clock = at
	for tech in s.tech_tree.researched:
		known[tech] = true
	return _after_dawn(max_seconds)


## Start on the new era: Alloying is the goal. Called at the moment Bronze Dawn is won (by whatever steps the bot).
func begin_era_two() -> void:
	dawn_at = clock
	if on_dawn.is_valid():
		on_dawn.call(self)
	_aim()
	lines.append("%5.0f s  == Bronze Dawn: the land opens ==" % clock)


## True once the first Bronze is made (and when, in `bronze_at`).
func made_bronze() -> bool:
	if bronze_at < 0.0 and s.economy.inv.get("bronze", 0) > 0:
		bronze_at = clock
		if on_bronze.is_valid():
			on_bronze.call(self)
	return bronze_at >= 0.0


func _after_dawn(max_seconds: float) -> Dictionary:
	if s.won:
		begin_era_two()
		while clock < max_seconds and not made_bronze():
			step(true)
	var minutes := (bronze_at - dawn_at) / 60.0 if bronze_at >= 0.0 else -1.0
	return {"won": s.won, "seconds": dawn_at, "bronze_seconds": bronze_at, "minutes": minutes, "log": lines}


## The goal: Mining first (the Mine starts digging while Smelting is researched), then Alloying, and once the first
## Bronze is made, The Falling Star.
func _aim() -> void:
	var want := "alloying" if s.tech_tree.researched.has("mining") else "mining"
	if bronze_at >= 0.0:
		want = "falling_star"
	if want != goal_tech or s.tech_tree.goal == "":
		goal_tech = want
		s.tech_tree.set_goal(goal_tech)


func _decide() -> void:
	if not s.won:
		super._decide()
		return
	_aim()
	_flood_reach()
	if _explore_ore() or _place_mine():
		return
	if bronze_at >= 0.0 and _build_for_the_star():
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
	if bronze_at >= 0.0:  # past the first Bronze: the Cart Shed, the Watchtower and one more Mine are to be paid for
		for type in ["cart_shed", "watchtower"]:
			if s.town.unlocked(type) and _count(type) < 1:
				_want(want, Data.BUILDINGS[type]["cost"], 1)
		for type in STAR_WORKSHOPS:
			if s.town.unlocked(type) and _count(type) < STAR_WORKSHOPS[type]:
				_want(want, Data.BUILDINGS[type]["cost"], 1)
		_want(want, Data.BUILDINGS["mine"]["cost"], 1)


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
	var edge := _first_step_beyond_reach(target)
	if edge.x < 0:
		return false
	if s.world.tile_at(edge) == "river" and s.fog.is_revealed(edge):
		return _bridge(edge)
	return _explore_to(edge)


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


# --- On to The Falling Star ----------------------------------------------------


## After the first Bronze: the buildings the era's later techs give (a Cart Shed, a Watchtower), and more Mines for the
## ore the Smelter and Crucible are short of. One placement a decision.
func _build_for_the_star() -> bool:
	if s.town.unlocked("cart_shed") and _count("cart_shed") < 1 and _place_near_hearth("cart_shed"):
		return true
	if s.town.unlocked("watchtower") and _count("watchtower") < 1 and _place_near_hearth("watchtower"):
		return true
	for type in ["smelter", "crucible"]:  # the era's later techs cost a great deal of Copper and Bronze
		if s.town.unlocked(type) and _count(type) < STAR_WORKSHOPS[type] and _place_near_hearth(type):
			return true
	if not s.town.unlocked("mine"):
		return false
	var ore_short: int = _short().get("copper_ore", 0)
	var copper_wanted := 1 + clampi(int(ore_short / MINE_ORE), 0, MINES_COPPER - 1)
	if _mines_on("copper_hills") < copper_wanted and _place_mine_on("copper_hills"):
		return true
	return _ore_seen("tin_stream") and _mines_on("tin_stream") < MINES_TIN and _place_mine_on("tin_stream")


## Mines that stand on `tile` (copper_hills or tin_stream).
func _mines_on(tile: String) -> int:
	var n := 0
	for b in s.town.buildings:
		if b["type"] == "mine" and s.world.tile_at(b["pos"]) == tile:
			n += 1
	return n


## A Mine on the `tile` nearest the Hearth that has none yet.
func _place_mine_on(tile: String) -> bool:
	var near := func(p):
		if s.world.tile_at(p) != tile:
			return -INF
		return -Vector2(p).distance_to(Vector2(s.world.camp_pos))
	return _place_best("mine", near)
