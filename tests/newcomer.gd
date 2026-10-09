extends RefCounted
## A first-time player, scripted. It only does what the Goals panel asks, in order: it holds the mouse on
## what the goal needs, researches what it names, places what it says to place and clicks what it says to click.
## It doesn't plan ahead, craft for later or read the rest of the game. Its `mode`:
##   "literal"  follows the goal text to the letter: a hut beside the Berry Bushes, then one click on it for a trip.
##              After that it reacts only to the food warning, as the toast says: click the berry hut for a trip (or,
##              with no berry hut, hold the mouse on Berry Bushes). Otherwise it idles.
##   "once"     playtest 4's clumsy newcomer: follows the goals and clicks each hut exactly once (the first trip goal,
##              and the berry hut it has just placed), then never clicks a hut again. It ignores the food warning.
##   "one_hut"  two huts on Berry Bushes, and it keeps clicking only the first whenever its trips run out. The other
##              is never clicked, the warning is ignored, and it does nothing else.
## The `idler` variant does nothing at all. It records what every hut's worker carries out (`gathered`) and the
## least food it ever held. tests/newcomer_tests.gd plays them and checks that the Kith stay fed, or that a warning
## came before anyone left.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Hands = preload("res://scripts/hands.gd")
const Workers = preload("res://scripts/workers.gd")
const World = preload("res://scripts/world.gd")

const DT := 0.1
const THINK := 1.0  # seconds between decisions
## A newcomer keeps the mouse on the map only about half the time: the rest is looking around and reading.
const ATTENTION := 0.5
const ATTENTION_CYCLE := 4.0
## A player takes this long to read a new goal or a warning before acting on it.
const READ_TIME := 3.0
## The tile that holds each good the goals ask for by hand.
const RAW_TILE := {
	"wood": "tree",
	"stone": "rock",
	"flint": "gravel",
	"fiber": "flax",
	"clay": "clay",
	"berries": "berry",
	"grain": "grain",
}
## Where a hut goes: next to any of these tiles, so it has something to gather.
const HUT_TILES := ["tree", "rock"]

var s: Sim
var idler := false  # does nothing at all
var mode := "literal"  # see the top of the file
var clock := 0.0
var think := 0.0
var warned_at := -1.0  # when the food warning first came, -1 if it never did
var left_at := -1.0  # when the first Kith left, -1 if none did
var left := 0  # how many left
var zeros := 0  # how many times the food ran out (went from something to nothing)
var recovered_at := -1.0  # when the warning came down again after coming up, -1 if it has not
var foraging_steps := 0  # steps in which some Kith was out foraging in a famine
var runway_at_warning := -1.0  # seconds of food left when the warning came
var min_kith := 0  # the fewest Kith alive at any time
var min_food := INF  # the least food (in food units) the stockpile ever held
var gathered := {}  # hut tile -> {item: how many its worker carried out}, counted once per bundle picked up
var hold_tile := Vector2i(-1, -1)
var trips_sent := 0
var reading := 0.0  # seconds still spent reading the panel: hands off the mouse
var _reading_for := ""  # what the player last read: a goal id, or "warning"
var _carrying := {}  # hut tile -> its worker was carrying something at the last step
var _click_new_hut := false  # the goal said to click the berry hut it just placed
var _at_zero := false


func play(map_seed: int, seconds: float) -> void:
	var game := Sim.new()
	game.generate(map_seed)
	attach(game)
	while clock < seconds:
		step()


func attach_game(map_seed: int) -> void:
	var game := Sim.new()
	game.generate(map_seed)
	attach(game)


func attach(game: Sim) -> void:
	s = game
	min_kith = s.people.kith.size()


## One DT: the game ticks, the player sees its messages, and every THINK seconds decides what to do.
func step() -> void:
	s.tick(DT)
	for e in s.events:
		if e == Data.FOOD_LOW_EVENT % Data.PEOPLE["many"] and warned_at < 0.0:
			warned_at = clock
			runway_at_warning = s.economy.seconds_of_food()
		elif e == Data.LEFT_EVENT % Data.PEOPLE["one"]:
			left += 1
			if left_at < 0.0:
				left_at = clock
	s.events.clear()
	clock += DT
	min_kith = mini(min_kith, s.people.kith.size())
	min_food = minf(min_food, s.economy.food_total())
	if s.economy.food_total() <= 0.0 and not _at_zero:
		zeros += 1
	_at_zero = s.economy.food_total() <= 0.0
	if warned_at >= 0.0 and recovered_at < 0.0 and not s.economy.low:
		recovered_at = clock
	_watch_huts()
	for k in s.people.kith:
		if String(k["phase"]).begins_with("forage"):
			foraging_steps += 1
			break
	if idler:
		return
	think -= DT
	reading = maxf(reading - DT, 0.0)
	if think <= 0.0:
		think = THINK
		_decide()
	if hold_tile.x >= 0 and reading <= 0.0 and fmod(clock, ATTENTION_CYCLE) < ATTENTION * ATTENTION_CYCLE:
		if Hands.item_at(s, hold_tile) == "":
			hold_tile = Vector2i(-1, -1)
			s.release_harvest()
		else:
			s.hold_harvest(hold_tile, DT)


## Note each new bundle a hut's worker picks up, by item.
func _watch_huts() -> void:
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] != "gatherer" or b["worker"] < 0:
			continue
		var carry: Dictionary = s.people.kith[b["worker"]]["carry"]
		if not carry.is_empty() and not _carrying.get(b["pos"], false):
			var got: Dictionary = gathered.get(b["pos"], {})
			for id in carry:
				got[id] = got.get(id, 0) + carry[id]
			gathered[b["pos"]] = got
		_carrying[b["pos"]] = not carry.is_empty()


## Click a Berry hut that has a worker and no trip queued, for a trip. `first_only` looks at the first Berry hut
## alone, the one this player ever clicks. Returns true when a click was made.
func _click_berry_hut(first_only := false) -> bool:
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		if b["focus"] != "berries":
			continue
		if b["worker"] >= 0 and b["trips"] == 0 and s.people.knows_focus(b):
			Workers.click(s, i)
			trips_sent += 1
			return true
		if first_only:
			return false
	return false


func _berry_huts() -> int:
	var n := 0
	for b in s.town.buildings:
		n += 1 if b["focus"] == "berries" else 0
	return n


func _decide() -> void:
	if mode == "one_hut":
		_click_berry_hut(true)
	elif _click_new_hut and _click_berry_hut():
		_click_new_hut = false  # "then click it to send a trip"
	if mode == "literal" and s.economy.low:  # the toast: click your berry hut, or hold on the bushes
		_read("warning")
		if not _click_berry_hut():
			_hold_on("berries")
		return
	var i := s.story.current_goal()
	_read(Data.GOALS[i]["id"] if i < Data.GOALS.size() else "")
	if i >= Data.GOALS.size():
		_stop()
		return
	var g: Dictionary = Data.GOALS[i]
	if mode == "one_hut" and g["id"] != "hut" and _berry_huts() < 2 and s.story.goals_done.has("hut"):
		_build("gatherers_hut", "berry")  # a second hut on the bushes, which it then never clicks
		return
	if g.has("building"):
		_build(g["building"], "berry" if mode == "one_hut" and g["id"] == "hut" else "")
	elif g.has("tech"):
		_research(g["tech"])
	else:
		_goal(g["id"])


## Note what the player is looking at now; a change costs READ_TIME seconds of reading.
func _read(what: String) -> void:
	if what != _reading_for:
		_reading_for = what
		reading = READ_TIME
		s.release_harvest()


## The goals that name neither a tech nor a building.
func _goal(id: String) -> void:
	match id:
		"learn_wood":
			_hold_on("wood")
		"learn_berries":
			_hold_on("berries")
		"learn_stone":
			_hold_on("stone" if not s.people.knows("stone") else "flint")
		"flax":
			_hold_on("fiber")
		"tools":
			_craft_tools()
		"trip":
			_send_trip()
		"berries":
			_build("gatherers_hut", "berry")
		_:
			_stop()  # a goal this newcomer never gets to


func _stop() -> void:
	hold_tile = Vector2i(-1, -1)
	s.release_harvest()


func _hold_on(item: String) -> void:
	var p := _nearest_tile(RAW_TILE[item], s.world.camp_pos)
	if p != hold_tile:
		s.release_harvest()
	hold_tile = p


## Click the tech (it is queued behind what it needs), then gather what the next one in the queue lacks.
func _research(tech: String) -> void:
	if s.tech_tree.goal != tech:
		s.tech_tree.set_goal(tech)
	for next in s.tech_tree.queue:
		if s.tech_tree.requirements_met(next) and not s.tech_tree.can_research(next):
			_gather_for(Data.TECHS[next]["cost"])
			return
	_stop()


## Craft a Flint Tool once the stockpile has what it takes, else gather what's missing.
func _craft_tools() -> void:
	var need: Dictionary = Data.RECIPES["flint_tools"]["in"]
	if s.economy.can_afford(need):
		if not Hands.craft(s, "flint_tools"):
			_stop()
		_stop()
	else:
		_gather_for(need)


## Place `type` where the goal says. `near` is the tile kind it must gather from ("" for any of HUT_TILES,
## or beside the Hearth for anything that isn't a hut).
func _build(type: String, near: String) -> void:
	if not s.town.unlocked(type):
		_research(Data.BUILDINGS[type]["tech"])
		return
	var cost: Dictionary = s.town.price(type)
	if not s.economy.can_afford(cost):
		_gather_for(cost)
		return
	var site := _site(type, near)
	if site.x >= 0 and s.place(type, site) and near == "berry":
		_click_new_hut = true
	_stop()


## The nearest free spot to the Hearth where `type` is allowed (and, for a hut, sits by `near` tiles).
func _site(type: String, near: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var camp := s.world.camp_pos
	for y in range(camp.y - 9, camp.y + 10):
		for x in range(camp.x - 9, camp.x + 10):
			var p := Vector2i(x, y)
			if s.town.placement_error(type, p) != "":
				continue
			if type == "gatherers_hut" and not _gathers(p, near):
				continue
			var d := Vector2(p).distance_to(Vector2(camp))
			if d < best_d:
				best = p
				best_d = d
	return best


## Would a hut at p be beside what the goal names? A hut works the resource nearest it, so "right beside
## Berry Bushes" means the bushes are what it would start on.
func _gathers(p: Vector2i, near: String) -> bool:
	if near != "":
		return s.town.default_focus(p) == Data.TILES[near]["yields"]
	for t in s.town.gather_tiles(p):
		if s.world.tile_at(t) in HUT_TILES:
			return true
	return false


## Hold the mouse on the raw good this cost is furthest short of.
func _gather_for(cost: Dictionary) -> void:
	var best := ""
	var best_short := 0
	for id in cost:
		var short: int = cost[id] - s.economy.inv.get(id, 0)
		if short > best_short and RAW_TILE.has(id) and _nearest_tile(RAW_TILE[id], s.world.camp_pos).x >= 0:
			best = id
			best_short = short
	if best == "":
		_stop()  # nothing it can gather by hand is missing
	else:
		_hold_on(best)


## Click the first hut that has a Kith who knows what's around it, once per goal (the first trip).
func _send_trip() -> void:
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		if Data.BUILDINGS[b["type"]]["kind"] == "gatherer" and b["worker"] >= 0 and s.people.knows_focus(b):
			Workers.click(s, i)
			trips_sent += 1
			return
	_stop()


func _nearest_tile(tile: String, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in World.HEIGHT:
		for x in World.WIDTH:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == tile and Hands.item_at(s, p) != "":
				var d := Vector2(p).distance_to(Vector2(from))
				if d < best_d:
					best = p
					best_d = d
	return best
