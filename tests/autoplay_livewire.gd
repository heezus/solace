extends "res://tests/autoplay_ironfall.gd"
## The headless player for Livewire (design-system/23-livewire.md): from the Ironfall gate (it plays Ironfall first, so the
## town is one it earned) to the Skyward tech. It does what a player does for the gate: Power Poles and a Generator, Wire Mills
## on the net, the Order Board with five orders written, a chain of poles south to the coal mines and an Arc Lamp pair and a
## Scorcher there to hold the Bloom's tide. It uses only the public Sim calls a player has (place, research, the Board's
## orders) and logs the clock at each Livewire goal.
## play_livewire(game, max_seconds) returns {"won" (Skyward was researched), "seconds" (the clock then, -1 for never),
## "gate_seconds" (the clock at the Ironfall gate), "marks", "log"}; tests/tools/pace.gd prints it.

const SKYWARD := "skyward"
## The techs in the order the bot takes them: the net and the Generator first, the lamps that hold the tide, then the Board's
## slots, then the factory techs, then the gate.
const TECH_ORDER := [
	"power_poles",
	"generator",
	"order_board",
	"tide_watch",
	"arc_lamps",
	"scorcher",
	"foremen",
	"factory_floor",
	"chain_orders",
	"shard_dynamo",
	SKYWARD,
]
const WIRE_MILLS := 3
const GENERATORS := 2
const WIRE_PER_MILL := 60.0  # one more Wire Mill for every this much Wire still short
const COAL_FOR_ENGINES := 200  # coal the Generators and the Scorcher burn, kept in the stores beyond the techs' needs
const CHARCOAL_FOR_ENGINES := 300  # Charcoal the engines are asked for once Coal runs low (a Charcoal lasts half as long as a Coal)
const SCORCHER_AHEAD := 3  # tiles ahead of the front's nearest ground the Scorcher stands (its reach is 4)
const SCORCHER_WAIT := 300.0  # seconds a Scorcher may stand with nothing in reach before the bot moves it
const SCORCHER_MOVES := 3  # times the bot moves a Scorcher in all
const FIREBREAK_RING := 3  # tiles from a site (the southern mine, a far Generator) to its ring of Firebreaks
const FIREBREAK_CAP := 60  # Firebreaks the bot lays in all
const POLE_STUCK := 12  # decisions without a new pole before the bot gives the southern net up
const ORDER_PLAN := [
	{"item": "brick", "compare": "above", "number": 500, "verb": "pause", "target": "kiln"},
	{"item": "iron_ore", "compare": "above", "number": 600, "verb": "pause", "target": "mine"},
	{"item": "wire", "compare": "above", "number": 200, "verb": "pause", "target": "wire_mill"},
	{"item": "rope", "compare": "above", "number": 200, "verb": "pause", "target": "twine_post"},
	{"item": "coal", "compare": "below", "number": 40, "verb": "bring", "target": "scorcher"},
]
const LIVEWIRE_TRACED := ["generator", "wire_mill", "arc_lamp", "scorcher", "order_board"]

var coal_gift := 0  # coal handed over when Livewire begins: a what-if for measuring the rest of the era without the coal limit
var watch := {}  # checkpoint id -> the mark whose arrival sets it off (a stage start worth keeping)
var on_checkpoint: Callable = func(_id: String, _bot): pass  # (id, this bot) when a watched mark arrives
var stop_when_watched := false  # stop playing once every watched checkpoint has been reached
var answer_tide := true  # false: the variant that lights a Generator and never answers the tide (no Lamp, Scorcher or Firebreak)
var skyward_at := -1.0
var _stuck_poles := 0
var _scorcher_idle := {}  # a Scorcher tile -> the clock when it was first seen with nothing in reach
var _scorcher_moves := 0
var _livewire_goals := {}


## Play `game` (an Ironfall start) through the Ironfall gate and on to Skyward, or until `max_seconds` pass.
func play_livewire(game: Sim, max_seconds: float) -> Dictionary:
	goal_tech = gate
	attach(game)
	for tech in s.tech_tree.researched:
		known[tech] = true
	_note_goals()
	_drop_stranded_posts()
	var ironfall_at := -1.0
	while clock < max_seconds and skyward_at < 0.0 and not (stop_when_watched and watch.is_empty()):
		if gate_at >= 0.0 and gate == GATE:  # the Wires Hum card is put away: Livewire begins
			ironfall_at = gate_at
			gate = SKYWARD
			s.story.record(Data.LIVEWIRE_EVENT)
			if coal_gift > 0:
				s.economy.add("coal", coal_gift)
				lines.append("%5.0f s  == what-if: %d coal handed over ==" % [clock, coal_gift])
			lines.append("%5.0f s  == Livewire begins ==" % clock)
		step(true)
	return {"won": skyward_at >= 0.0, "seconds": skyward_at, "gate_seconds": ironfall_at, "marks": marks, "log": lines}


## Hand each watched checkpoint whose mark has arrived to `on_checkpoint`, once.
func _checkpoints() -> void:
	for id in watch.keys():
		if marks.has(watch[id]):
			watch.erase(id)
			on_checkpoint.call(id, self)


func _livewire_open() -> bool:
	return gate == SKYWARD and Data.LIVEWIRE_BEGUN in s.story.events


## The techs in order: whichever of TECH_ORDER is first and not yet learned is the goal, so the lamps are up before the
## factory techs take the Steel. Ironfall's own order until the gate is through.
func _aim() -> void:
	if gate != SKYWARD:
		super._aim()
		return
	var want := SKYWARD
	for id in TECH_ORDER:
		if not s.tech_tree.researched.has(id):
			want = id
			break
	if s.tech_tree.goal != want:
		s.tech_tree.set_goal(want)


func _note_goals() -> void:
	super._note_goals()
	for g in Data.GOALS_ERA5:
		if s.story.goals_done.has(g["id"]) and not _livewire_goals.has(g["id"]):
			_livewire_goals[g["id"]] = true
			marks[g["id"]] = clock
	if skyward_at < 0.0 and s.tech_tree.researched.has(SKYWARD):
		skyward_at = clock
		marks["skyward"] = clock
	if Data.LIVEWIRE_BEGUN in s.story.events and not marks.has("livewire_begins"):
		marks["livewire_begins"] = clock
	if s.tide.begun and not marks.has("tide_begins"):
		marks["tide_begins"] = clock
	if s.tide.lost > 0 and not marks.has("first_loss"):
		marks["first_loss"] = clock
	_checkpoints()


## Wire, and the coal the engines burn, on top of the metal works' wants.
func _goal_wants(want: Dictionary) -> void:
	super._goal_wants(want)
	if not _livewire_open():
		return
	var wire := _wire_short()
	if wire > 0:
		want["wire"] = want.get("wire", 0) + _route_cost("wire")
		want["copper"] = want.get("copper", 0) + wire
	for type in _livewire_wants():
		_want(want, s.town.price(type), 1)
	want["coal"] = want.get("coal", 0) + COAL_FOR_ENGINES
	if _inv("coal") < Data.FUEL_RESERVE * 2:  # Coal short: engines and Scorchers take Charcoal, so the bot makes some for them
		want["charcoal"] = want.get("charcoal", 0) + CHARCOAL_FOR_ENGINES


func _gate_need(id: String) -> int:
	var need := super._gate_need(id)
	if id == "coal" and _livewire_open():
		need += COAL_FOR_ENGINES
	return need


func _wire_short() -> int:
	return maxi(_route_cost("wire") - _inv("wire"), 0)


func _livewire_wants() -> Array:
	var out: Array = []
	for type in ["power_pole", "generator", "order_board", "wire_mill", "arc_lamp", "scorcher"]:
		if s.town.unlocked(type) and _count(type) < _livewire_target(type):
			out.append(type)
	return out


func _livewire_target(type: String) -> int:
	match type:
		"power_pole":
			return 40
		"generator":
			return 1 if _count("generator") == 0 or not _net_short() else GENERATORS
		"order_board":
			return 1
		"wire_mill":
			return mini(1 + int(_wire_short() / WIRE_PER_MILL), WIRE_MILLS) if _wire_short() > 0 else _count(type)
		"arc_lamp":
			return 2
		"scorcher":
			return 1
	return 0


## True while a net gives less than its machines ask.
func _net_short() -> bool:
	for n in s.livewire.nets:
		if n["asks"] > n["given"] and n["given"] > 0:
			return true
	return false


# --- Building -----------------------------------------------------------------


## One placement for the era's own buildings; false when none is due or affordable.
func _build_ironfall() -> bool:
	if _livewire_open():
		_write_orders()
		if _build_livewire():
			return true
	return super._build_ironfall()


func _build_livewire() -> bool:
	if _place_board():
		return true
	if _place_generator():
		return true
	if _lay_hub_pole():
		return true
	if _place_wire_mill():
		return true
	if _lay_south_poles():
		return true
	if not answer_tide:
		return false
	return _place_south("arc_lamp") or _move_scorcher() or _place_scorcher() or _lay_firebreaks()


## The Order Board beside the Hearth; a full town gives up a Gatherer's Hut for it.
func _place_board() -> bool:
	if not s.town.unlocked("order_board") or _count("order_board") >= 1:
		return false
	if _place_best("order_board", func(p): return -Vector2(p).distance_to(Vector2(s.world.camp_pos))):
		return true
	return _make_room_for("order_board")


## A Generator near the Boiler (where the coal goes), a second one when a net runs short.
func _place_generator() -> bool:
	if not s.town.unlocked("generator") or _count("generator") >= _livewire_target("generator"):
		return false
	var home := _anchor()
	return _place_best("generator", func(p): return -Vector2(p).distance_to(Vector2(home)))


## Where the metal works stand: the first Boiler, or the Hearth.
func _anchor() -> Vector2i:
	for b in s.town.buildings:
		if b["type"] == "boiler":
			return b["pos"]
	return s.world.camp_pos


func _poles() -> Array:
	var out: Array = []
	for b in s.town.buildings:
		if b["type"] == "power_pole":
			out.append(b["pos"])
	return out


## True when tile p is within a pole's reach.
func _on_net(p: Vector2i) -> bool:
	for q in _poles():
		if Vector2(q).distance_to(Vector2(p)) <= Data.POLE_REACH:
			return true
	return false


## A first Pole beside the Generator, so the net has a heart.
func _lay_hub_pole() -> bool:
	if not s.town.unlocked("power_pole") or _count("generator") == 0 or not _poles().is_empty():
		return false
	var gen := Vector2i(-1, -1)
	for b in s.town.buildings:
		if b["type"] == "generator":
			gen = b["pos"]
			break
	return _place_best(
		"power_pole",
		func(p):
			var d := Vector2(p).distance_to(Vector2(gen))
			return -d if d >= 1.0 and d <= Data.POLE_REACH else -INF
	)


## Wire Mills on the net, as many as the Wire still short asks for.
func _place_wire_mill() -> bool:
	if not s.town.unlocked("wire_mill") or _count("wire_mill") >= _livewire_target("wire_mill") or _poles().is_empty():
		return false
	var home := _anchor()
	var score := func(p): return -Vector2(p).distance_to(Vector2(home)) if _on_net(p) else -INF
	return _place_best("wire_mill", score)


## The tile the southern net runs to: beside the Coal Mine (or Mine) in the south land nearest the Hearth, or straight south.
func _south_target() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for b in s.town.buildings:
		if b["type"] in ["coal_mine", "mine"] and s.gate.in_south(b["pos"]):
			var d := Vector2(b["pos"]).distance_to(Vector2(s.world.camp_pos))
			if d < best_d:
				best = b["pos"]
				best_d = d
	if best.x >= 0:
		return best
	return s.world.camp_pos + Vector2i(0, Data.SOUTH_ROWS_BELOW_HEARTH + 1)


## The next Pole of the chain toward the south target: the free tile within POLE_LINK of a standing pole that is nearest to it.
func _lay_south_poles() -> bool:
	if not s.town.unlocked("power_pole") or _poles().is_empty() or _stuck_poles >= POLE_STUCK:
		return false
	if _count("arc_lamp") >= _livewire_target("arc_lamp") and _count("scorcher") >= _livewire_target("scorcher"):
		return false
	var target := _south_target()
	var from := Vector2i(-1, -1)
	var from_d := INF
	for q in _poles():
		var d := Vector2(q).distance_to(Vector2(target))
		if d < from_d:
			from = q
			from_d = d
	if from_d <= Data.POLE_REACH - 0.5:
		return false  # the net is there
	var score := func(p):
		var d := Vector2(p).distance_to(Vector2(from))
		if d < 1.5 or d > Data.POLE_LINK:
			return -INF
		var left := Vector2(p).distance_to(Vector2(target))
		return -INF if left >= from_d else -left
	if _place_best("power_pole", score):
		_stuck_poles = 0
		return true
	if s.economy.can_afford(s.town.price("power_pole")):
		_stuck_poles += 1
	return false


## A lit building of `type` in the south land, on the net, nearest the target.
func _place_south(type: String) -> bool:
	if not s.town.unlocked(type) or _count(type) >= _livewire_target(type):
		return false
	var target := _south_target()
	var score := func(p):
		if not s.gate.in_south(p) or not _on_net(p):
			return -INF
		return -Vector2(p).distance_to(Vector2(target))
	return _place_best(type, score)


## A Scorcher on the net where the front will come into its reach: SCORCHER_AHEAD tiles from the Bloom's nearest ground, on the
## side of the Hearth (or of the Generator) the front is coming from. Without any front yet it stands by the southern net as before.
func _place_scorcher() -> bool:
	if not s.town.unlocked("scorcher") or _count("scorcher") >= _livewire_target("scorcher"):
		return false
	var site := _south_target()
	var from := _front_near(site)
	if from.x < 0:
		return _place_south("scorcher")
	var score := func(p):
		if not _on_net(p):
			return -INF
		var ahead := Vector2(p).distance_to(Vector2(from))
		return -absf(ahead - SCORCHER_AHEAD) - 0.05 * Vector2(p).distance_to(Vector2(site))
	return _place_best("scorcher", score)


## Move a Scorcher that has had nothing in reach for SCORCHER_WAIT seconds: take it down (its price comes back in part) so
## `_place_scorcher` puts it where the front is now. At most SCORCHER_MOVES times, and only once Bloom ground is on the map.
func _move_scorcher() -> bool:
	if _scorcher_moves >= SCORCHER_MOVES or s.tide.grown.is_empty():
		return false
	for b in s.town.buildings:
		if b["type"] != "scorcher":
			continue
		var at: Vector2i = b["pos"]
		if s.tide.scorch_target(b).x >= 0 or b["trips"] > 0:
			_scorcher_idle.erase(at)
			continue
		if not _scorcher_idle.has(at):
			_scorcher_idle[at] = clock
		if clock - _scorcher_idle[at] >= SCORCHER_WAIT:
			_scorcher_idle.erase(at)
			_scorcher_moves += 1
			s.demolish(at)
			lines.append("%5.0f s    moved the Scorcher at %s (nothing in reach)" % [clock, at])
			return true
	return false


## A ring of Firebreaks round the southern mine and any Generator well out from the Hearth, the side facing the front first, once
## Tide Watch and Firebreaks are learned: the front must cross a Firebreak (10 times as long) or walk round the whole ring. A road
## leaves a gap in it. One tile a decision, and only from wood and stone the techs and workshops do not need.
func _lay_firebreaks() -> bool:
	if not s.tide.begun or not s.town.unlocked("firebreak") or _count("firebreak") >= FIREBREAK_CAP:
		return false
	var price: Dictionary = s.town.price("firebreak")
	for id in price:
		if _spare(id) < price[id]:
			return false
	var sites: Array = []
	var south := _south_target()
	if s.gate.in_south(south):
		sites.append(south)
	for b in s.town.buildings:
		if (
			b["type"] == "generator"
			and Vector2(b["pos"]).distance_to(Vector2(s.world.camp_pos)) > Data.TIDE_HEARTH_RING + 3.0
		):
			sites.append(b["pos"])
	var rank := {}  # ring tile -> how near it lies to the front: nearer first
	for site in sites:
		var from := _front_near(site)
		if from.x < 0:
			continue
		for dy in range(-FIREBREAK_RING, FIREBREAK_RING + 1):
			for dx in range(-FIREBREAK_RING, FIREBREAK_RING + 1):
				if maxi(absi(dx), absi(dy)) == FIREBREAK_RING:
					var p: Vector2i = site + Vector2i(dx, dy)
					rank[p] = -Vector2(p).distance_to(Vector2(from))
	if rank.is_empty():
		return false
	return _place_best("firebreak", func(p): return rank.get(p, -INF))


## The tile of the Bloom's front (or its ground) nearest `site`, (-1, -1) when there is none.
func _front_near(site: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for p in s.tide.front:
		var d := Vector2(p).distance_to(Vector2(site))
		if d < best_d:
			best = p
			best_d = d
	return best


# --- Orders -------------------------------------------------------------------


## Write the Board's orders from the plan, as many as its slots hold, each with its building chosen.
func _write_orders() -> void:
	if not s.livewire.has_board(s):
		return
	var i := 0
	while i < ORDER_PLAN.size():
		var plan: Dictionary = ORDER_PLAN[i]
		if s.livewire.orders.size() <= i:
			if not s.livewire.add(s):
				return
		var o: Dictionary = s.livewire.orders[i]
		if o["target"] == "" and s.town.unlocked(plan["target"]):
			o.merge(plan, true)
			lines.append("%5.0f s  == order written: %s ==" % [clock, s.livewire.text(o)])
		i += 1


func _trace() -> void:
	super._trace()
	if not _livewire_open():
		return
	var seen := {}
	for b in s.town.buildings:
		if b["type"] in LIVEWIRE_TRACED:
			var key: String = "%s:%s" % [b["type"], String(b["status"]).substr(0, 24)]
			seen[key] = seen.get(key, 0) + 1
	var nets: Array = s.livewire.nets.map(func(n): return "%d/%d" % [n["given"], n["asks"]])
	(
		lines
		. append(
			(
				"        livewire: poles %d, nets given/asked %s, orders %d (%d holding), tide lost %d, wire %d steel %d coal %d | %s"
				% [
					_poles().size(),
					nets,
					s.livewire.orders.size(),
					s.livewire.holding_count(),
					s.tide.lost,
					_inv("wire"),
					_inv("steel"),
					_inv("coal"),
					seen
				]
			)
		)
	)
