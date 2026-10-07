extends RefCounted
## The Research block: which techs are researched, what each one still needs, the research goal and the
## queue of techs on the way to it (up to Data.QUEUE_SLOTS at a time, each researched as soon as it is
## affordable). It stands alone and never reaches into another block. Costs are paid through the Economy
## handed in at construction, and whether hidden techs are on show comes in as a read-only callable.
## What happens in the world when a tech completes (a new road speed, the fog, a win) is not decided
## here: research() and tick() only report which techs were completed, and their owner reacts.
## Sim owns one, reached as `sim.tech_tree`.
## Signal: tech_researched(id) fires once for each tech as it completes (Story and the owner listen).

signal tech_researched(id: String)

const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Rules = preload("res://scripts/rules.gd")

var researched: Dictionary  # tech id -> true (the Economy reads the same set as a view, and never writes it)
var goal := ""  # the tech the queue is working toward, "" for none
var queue: Array = []  # the next techs on the way there, researched as soon as affordable
var story_has: Callable = func(_id): return false  # (String) -> bool: has that story moment happened? Set by the owner
var _economy: Economy
var _hidden_shown: Callable  # () -> bool: true once hidden techs are on show (the Strange Stone was clicked)
var _extra_discount: Callable  # () -> float: a share (0 to 1) off every tech, from what stands in the town; may be unset
var _vis: Dictionary = {}  # tech id -> true: the techs in view, worked out again whenever what they depend on changes
var _vis_key := ""


## `researched_set` is the dictionary the Economy also holds (built first, since each needs the other).
func _init(economy: Economy, researched_set: Dictionary, hidden_shown: Callable) -> void:
	_economy = economy
	researched = researched_set
	_hidden_shown = hidden_shown


## `discount` is a () -> float: the share (0 to 1) the town takes off every tech (the Sim passes the Buildings block's).
func set_extra_discount(discount: Callable) -> void:
	_extra_discount = discount


# --- Requirements ------------------------------------------------------------


## A tech is in view once the Kith have had every item it costs in their hands (the Economy's `seen`, or what is in the
## stockpile now: the start items, whatever was gathered by hand or hauled in, whatever was crafted) and every tech
## it needs is in view too. A researched tech always is. Hidden techs (Star Lore) also wait for the Strange Stone to
## be clicked. Nothing about a tech shows before then: not its card, a route through it, a suggestion or a tooltip.
func tech_visible(tech: String) -> bool:
	return visible_set().has(tech)


## Every tech in view (see tech_visible), as tech id -> true. Cached until an item is first seen, a tech is researched
## or the Strange Stone is clicked.
func visible_set() -> Dictionary:
	var shown: bool = _hidden_shown.call()
	var held := 0
	for id in _economy.inv:
		if _economy.inv[id] > 0:
			held += 1
	var after := Data.TECH_AFTER_EVENTS.filter(func(id): return story_has.call(id)).size()
	var key := "%d|%d|%d|%s|%d" % [_economy.seen.size(), held, researched.size(), shown, after]
	if key == _vis_key:
		return _vis
	_vis_key = key
	_vis = {}
	var changed := true
	while changed:  # parents first, however the tree is ordered
		changed = false
		for tech in Data.TECHS:
			if not _vis.has(tech) and (researched.has(tech) or _discovered(tech, shown)):
				_vis[tech] = true
				changed = true
	return _vis


func _discovered(tech: String, shown: bool) -> bool:
	var def: Dictionary = Data.TECHS[tech]
	if def.get("hidden", false) and not shown:
		return false
	if def.has("after") and not story_has.call(def["after"]):
		return false  # a tech of a later era waits for the story moment that opens it
	if passed_over(tech):
		return false
	for item in def["cost"]:
		if not _economy.seen.has(item) and _economy.inv.get(item, 0) <= 0:
			return false
	for r in def["requires"]:
		if not _vis.has(r):
			return false
	var any: Array = def.get("requires_any", [])
	return any.is_empty() or any.any(func(r): return _vis.has(r))


## How many requirements are still open. A `requires_any` list counts as one.
func missing_requirements(tech: String) -> int:
	var def: Dictionary = Data.TECHS[tech]
	var n := 0
	for r in def["requires"]:
		if not researched.has(r):
			n += 1
	var any: Array = def.get("requires_any", [])
	if not any.is_empty() and not any.any(func(r): return researched.has(r)):
		n += 1
	return n


## True once `tech` is researched.
func unlocked(tech: String) -> bool:
	return researched.has(tech)


## The forks `tech` is a route of: the goals (techs with `fork`) whose `requires_any` names it.
static func fork_goals(tech: String) -> Array:
	return Data.TECH_ORDER.filter(
		func(g): return Data.TECHS[g].get("fork", false) and tech in Data.TECHS[g].get("requires_any", [])
	)


## True while `tech` is set aside by a fork: another route to the same goal is learned and the goal is not yet.
func passed_over(tech: String) -> bool:
	if researched.has(tech):
		return false
	for fork in fork_goals(tech):
		if researched.has(fork):
			continue
		if Data.TECHS[fork]["requires_any"].any(func(r): return r != tech and researched.has(r)):
			return true
	return false


## True when `tech` is a route the fork's goal has already been learned without: it costs Data.FORK_LATER_COST times as much.
func comes_later(tech: String) -> bool:
	if researched.has(tech):
		return false
	return fork_goals(tech).any(func(g): return researched.has(g))


func requirements_met(tech: String) -> bool:
	return tech_visible(tech) and missing_requirements(tech) == 0


## False for a tech whose effect isn't built yet (its `stage` is past Data.BUILT_STAGE): it shows on the board,
## locked, and can never be researched, so nobody pays for a tech that does nothing.
static func enabled(tech: String) -> bool:
	return Rules.tech_enabled(tech)


## What `tech` costs now: Tally Sticks makes every tech a tenth cheaper, and whatever the town reports as an extra
## discount (a Shard Cairn) takes a little more off. The two multiply and the item is rounded once, never to less than 1.
func cost_of(tech: String) -> Dictionary:
	var cost: Dictionary = Data.TECHS[tech]["cost"]
	var share := 1.0
	if comes_later(tech):
		share *= Data.FORK_LATER_COST
	if researched.has("tally_sticks"):
		share *= Data.TALLY_DISCOUNT
	if _extra_discount.is_valid():
		share *= 1.0 - float(_extra_discount.call())
	if share == 1.0:
		return cost
	var out := {}
	for id in cost:
		out[id] = maxi(roundi(cost[id] * share), 1)
	return out


func can_research(tech: String) -> bool:
	return not researched.has(tech) and enabled(tech) and requirements_met(tech) and _economy.can_afford(cost_of(tech))


## Pay for `tech` and mark it researched. Returns false, and takes nothing, when it can't be researched
## yet. A true result means the tech was just completed: the owner runs whatever that sets off.
func research(tech: String) -> bool:
	if not can_research(tech):
		return false
	_economy.pay(cost_of(tech))
	researched[tech] = true
	tech_researched.emit(tech)
	return true


# --- The goal and the queue --------------------------------------------------


func set_goal(tech: String) -> void:
	if tech != "" and not enabled(tech):
		return  # nothing to queue toward: it can't be researched yet
	goal = tech
	refill()


func clear() -> void:
	goal = ""
	queue = []


## Queue the next few techs on the way to the goal, parents first. The goal is dropped once reached.
func refill() -> void:
	if goal == "":
		queue = []
		return
	var route := Rules.route_to(goal, researched, visible_set())
	queue = route.slice(0, Data.QUEUE_SLOTS)
	if route.is_empty():
		goal = ""


## Research whatever in the queue has become affordable, then refill it. Returns the techs completed
## this call, in the order they were researched.
func tick() -> Array:
	var done: Array = []
	if queue.is_empty():
		return done
	var changed := false
	for tech in queue:
		if researched.has(tech):
			changed = true
		elif research(tech):
			done.append(tech)
			changed = true
	if changed:
		refill()
	return done


## Techs that can be researched right now, in tree order.
func ready_list() -> Array:
	return Data.TECH_ORDER.filter(func(t): return can_research(t))


# --- Save --------------------------------------------------------------------


## The researched techs (in the order they were researched), the goal and the queue, as JSON-safe values.
func to_dict() -> Dictionary:
	return {"researched": Codec.keys(researched), "goal": goal, "queue": queue.duplicate()}


## Restore what to_dict wrote. The researched set is refilled in place, since the Economy reads the same one.
## Nothing is emitted: the techs were already announced in the run that was saved.
func from_dict(d: Dictionary) -> void:
	researched.clear()
	researched.merge(Codec.to_set(d.get("researched", [])))
	goal = String(d.get("goal", ""))
	queue = Codec.strings(d.get("queue", []))
