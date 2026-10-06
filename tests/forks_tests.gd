extends RefCounted
## PR 3 of the growth batch (design-system/17-needs-and-upgrades.md): the trade routes to Granaries are a fork (two routes
## to one goal), and Megaliths wait for Star Lore. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Research = preload("res://scripts/research.gd")
const Sim = preload("res://scripts/sim.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_megaliths_need_star_lore_and_masonry()
	test_a_fork_sets_the_other_route_aside_until_its_goal()
	test_the_route_passed_over_costs_half_again_later()
	test_a_fork_never_strands_the_goal()
	test_forks_lead_to_their_goal()


## A new town with every item seen (these tests are about the rules for the cards) and `have` researched.
func _town(have: Array) -> Sim:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
	for id in have:
		s.tech_tree.researched[id] = true
	return s


func test_megaliths_need_star_lore_and_masonry() -> void:
	var def: Dictionary = Data.TECHS["megaliths"]
	t.check(def["requires"].has("star_lore") and def["requires"].has("masonry"), "Megaliths need Star Lore and Masonry")
	t.check(not def.has("requires_any"), "Storytelling is no way into Megaliths")
	var s := _town(["knapping", "fire", "masonry", "storytelling"])
	t.check(not s.tech_tree.requirements_met("megaliths"), "without Star Lore, Megaliths are not open")
	s.tech_tree.researched["star_lore"] = true
	t.check(s.tech_tree.requirements_met("megaliths"), "with Star Lore and Masonry, Megaliths are open")


func test_a_fork_sets_the_other_route_aside_until_its_goal() -> void:
	t.check(Data.TECHS["granaries"].get("fork", false), "Granaries are a fork")
	var s := _town(_before_granaries())
	t.check(s.tech_tree.tech_visible("markets") and s.tech_tree.tech_visible("kilns_ii"), "both routes show at first")
	s.tech_tree.researched["markets"] = true
	s.tech_tree.refill()
	t.check(s.tech_tree.passed_over("kilns_ii"), "Markets taken, Kilns II are passed over")
	t.check(not s.tech_tree.tech_visible("kilns_ii"), "and out of view")
	t.check(not s.tech_tree.can_research("kilns_ii"), "and not for sale")
	t.check(s.tech_tree.requirements_met("granaries"), "Granaries are open by the route taken")
	s.tech_tree.researched["granaries"] = true
	t.check(not s.tech_tree.passed_over("kilns_ii"), "once Granaries are learned the other route is back")
	t.check(s.tech_tree.tech_visible("kilns_ii"), "in view again")
	t.check(not s.tech_tree.passed_over("markets"), "a learned route is never passed over")


## What `tech` costs with Tally Sticks (learned in these towns) and `factor` on top, item by item.
func _price(tech: String, factor: float) -> Dictionary:
	var out := {}
	for id in Data.TECHS[tech]["cost"]:
		out[id] = maxi(roundi(Data.TECHS[tech]["cost"][id] * Data.TALLY_DISCOUNT * factor), 1)
	return out


func test_the_route_passed_over_costs_half_again_later() -> void:
	var s := _town(_before_granaries())
	t.check(s.tech_tree.cost_of("kilns_ii") == _price("kilns_ii", 1.0), "before the fork, a route costs its price")
	s.tech_tree.researched["markets"] = true
	t.check(s.tech_tree.cost_of("kilns_ii") == _price("kilns_ii", 1.0), "set aside, still its own price")
	s.tech_tree.researched["granaries"] = true
	t.check(
		s.tech_tree.cost_of("kilns_ii") == _price("kilns_ii", Data.FORK_LATER_COST),
		"after the goal, the other route costs half again: %s" % [s.tech_tree.cost_of("kilns_ii")]
	)
	t.check(s.tech_tree.cost_of("markets") == _price("markets", 1.0), "the route taken is not marked up")


func test_a_fork_never_strands_the_goal() -> void:
	for goal in Data.TECH_ORDER:
		if not Data.TECHS[goal].get("fork", false):
			continue
		var routes: Array = Data.TECHS[goal]["requires_any"]
		t.check(routes.size() >= 2, "%s: a fork has two routes at least" % goal)
		for taken in routes:
			var s := _town(Data.TECHS[goal]["requires"])
			# every tech under the goal and the routes is learned, then one route
			for tech in Data.TECH_ORDER:
				if tech != goal and tech not in routes and tech in _under(goal):
					s.tech_tree.researched[tech] = true
			s.tech_tree.researched[taken] = true
			t.check(s.tech_tree.requirements_met(goal), "%s: reachable by way of %s alone" % [goal, taken])


## The techs the goal and its routes need, however far back.
func _under(goal: String) -> Dictionary:
	var out := {}
	var todo: Array = [goal]
	while not todo.is_empty():
		var tech: String = todo.pop_back()
		for r in Data.TECHS[tech]["requires"] + Data.TECHS[tech].get("requires_any", []):
			if not out.has(r):
				out[r] = true
				todo.append(r)
	return out


## What stands under Granaries: Bronze Dawn and the Bronze Dawn techs the routes build on.
func _before_granaries() -> Array:
	return ["bronze_dawn", "prospecting", "tally_sticks", "plough", "smelting", "the_wheel"]


func test_forks_lead_to_their_goal() -> void:
	t.check(Research.fork_goals("markets") == ["granaries"], "Markets lead a fork to Granaries")
	t.check(Research.fork_goals("kilns_ii") == ["granaries"], "so do Kilns II")
	t.check(Research.fork_goals("plough").is_empty(), "and nothing else does")
