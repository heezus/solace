extends RefCounted
## A first-time player, scripted. It only does what the Goals panel asks, in order: it holds the mouse on
## what the goal needs, researches what it names, places what it says to place and sends the trip it is told
## to send. It doesn't plan ahead, craft for later or read the rest of the game. The one thing it reacts to
## besides the goals is the food warning: while the warning is up it holds on Berry Bushes, as any player who
## read the toast would. Otherwise it idles (a goal it can't do leaves it idle).
## The `idler` variant does nothing at all. tests/newcomer_tests.gd plays both and checks that the Kith stay
## fed, or that a warning came before anyone left.

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
var clock := 0.0
var think := 0.0
var warned_at := -1.0  # when the food warning first came, -1 if it never did
var left_at := -1.0  # when the first Kith left, -1 if none did
var left := 0  # how many left
var min_kith := 0  # the fewest Kith alive at any time
var hold_tile := Vector2i(-1, -1)
var trips_sent := 0
var reading := 0.0  # seconds still spent reading the panel: hands off the mouse
var _reading_for := ""  # what the player last read: a goal id, or "warning"


func play(map_seed: int, seconds: float) -> void:
	var game := Sim.new()
	game.generate(map_seed)
	attach(game)
	while clock < seconds:
		step()


func attach(game: Sim) -> void:
	s = game
	min_kith = s.people.kith.size()


## One DT: the game ticks, the player sees its messages, and every THINK seconds decides what to do.
func step() -> void:
	s.tick(DT)
	for e in s.events:
		if e == Data.FOOD_LOW_EVENT % Data.PEOPLE["many"] and warned_at < 0.0:
			warned_at = clock
		elif e == Data.LEFT_EVENT % Data.PEOPLE["one"]:
			left += 1
			if left_at < 0.0:
				left_at = clock
	s.events.clear()
	clock += DT
	min_kith = mini(min_kith, s.people.kith.size())
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


func _decide() -> void:
	if s.economy.low:  # the warning is up: hold on the berries until it goes down
		_read("warning")
		_hold_on("berries")
		return
	var i := s.story.current_goal()
	_read(Data.GOALS[i]["id"] if i < Data.GOALS.size() else "")
	if i >= Data.GOALS.size():
		_stop()
		return
	var g: Dictionary = Data.GOALS[i]
	if g.has("building"):
		_build(g["building"], "")
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
	var cost: Dictionary = Data.BUILDINGS[type]["cost"]
	if not s.economy.can_afford(cost):
		_gather_for(cost)
		return
	var site := _site(type, near)
	if site.x >= 0 and not s.place(type, site):
		site = Vector2i(-1, -1)
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


func _gathers(p: Vector2i, near: String) -> bool:
	var kinds := [near] if near != "" else HUT_TILES
	for t in s.town.gather_tiles(p):
		if s.world.tile_at(t) in kinds:
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
		if Data.BUILDINGS[b["type"]]["kind"] == "gatherer" and b["worker"] >= 0 and s.people.knows_any(b["pos"]):
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
