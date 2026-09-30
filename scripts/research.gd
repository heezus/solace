extends RefCounted
## The Research block: which techs are researched, what each one still needs, the research goal and the
## queue of techs on the way to it (up to Data.QUEUE_SLOTS at a time, each researched as soon as it is
## affordable). It stands alone and never reaches into another block. Costs are paid through the Economy
## handed in at construction, and whether hidden techs are on show comes in as a read-only callable.
## What happens in the world when a tech completes (a new road speed, the fog, a win) is not decided
## here: research() and tick() only report which techs were completed, and their owner reacts.
## Sim owns one and passes its old tech methods through to it.
## Signal: tech_researched(id) fires once for each tech as it completes (Story and the owner listen).

signal tech_researched(id: String)

const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Rules = preload("res://scripts/rules.gd")

var researched: Dictionary  # tech id -> true (the Economy reads the same set as a view, and never writes it)
var goal := ""  # the tech the queue is working toward, "" for none
var queue: Array = []  # the next techs on the way there, researched as soon as affordable
var _economy: Economy
var _hidden_shown: Callable  # () -> bool: true once hidden techs are on show (the Strange Stone was clicked)


## `researched_set` is the dictionary the Economy also holds (built first, since each needs the other).
func _init(economy: Economy, researched_set: Dictionary, hidden_shown: Callable) -> void:
	_economy = economy
	researched = researched_set
	_hidden_shown = hidden_shown


# --- Requirements ------------------------------------------------------------


## Hidden techs (Star Lore) only show once the Strange Stone has been clicked.
func tech_visible(tech: String) -> bool:
	return _hidden_shown.call() or not Data.TECHS[tech].get("hidden", false)


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


func requirements_met(tech: String) -> bool:
	return tech_visible(tech) and missing_requirements(tech) == 0


func can_research(tech: String) -> bool:
	return not researched.has(tech) and requirements_met(tech) and _economy.can_afford(Data.TECHS[tech]["cost"])


## Pay for `tech` and mark it researched. Returns false, and takes nothing, when it can't be researched
## yet. A true result means the tech was just completed: the owner runs whatever that sets off.
func research(tech: String) -> bool:
	if not can_research(tech):
		return false
	_economy.pay(Data.TECHS[tech]["cost"])
	researched[tech] = true
	tech_researched.emit(tech)
	return true


# --- The goal and the queue --------------------------------------------------


func set_goal(tech: String) -> void:
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
	var route := Rules.route_to(goal, researched, Rules.visible_techs(_hidden_shown.call()))
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
