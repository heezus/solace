extends RefCounted
## The research queue: click a far tech to make it the goal, and the techs it still needs line up
## (up to Data.QUEUE_SLOTS at a time). Each one is researched as soon as it's affordable.
## Static, and works on the GameState passed in (its research_goal and research_queue).

const Data = preload("res://scripts/data.gd")
const Rules = preload("res://scripts/rules.gd")


static func set_goal(s, tech: String) -> void:
	s.research_goal = tech
	refill(s)


static func clear(s) -> void:
	s.research_goal = ""
	s.research_queue = []


## Queue the next few techs on the way to the goal, parents first. The goal is dropped once reached.
static func refill(s) -> void:
	if s.research_goal == "":
		s.research_queue = []
		return
	var route := Rules.route_to(s.research_goal, s.researched, Rules.visible_techs(s.shard_seen))
	s.research_queue = route.slice(0, Data.QUEUE_SLOTS)
	if route.is_empty():
		s.research_goal = ""


## Research whatever in the queue has become affordable.
static func tick(s) -> void:
	if s.research_queue.is_empty():
		return
	var changed := false
	for tech in s.research_queue:
		if s.researched.has(tech):
			changed = true
		elif s.can_research(tech):
			s.research(tech)
			changed = true
	if changed:
		refill(s)


## Techs that can be researched right now, in tree order.
static func ready_list(s) -> Array:
	return Data.TECH_ORDER.filter(func(t): return s.can_research(t))
