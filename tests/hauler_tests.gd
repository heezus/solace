extends RefCounted
## Haulers (scripts/haulers.gd): where idle ones wait. Run from tests/run_tests.gd, which owns check() and the helpers.

const Roads = preload("res://scripts/roads.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Sim = preload("res://scripts/sim.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_haulers_wait_at_every_depot_with_work()
	test_the_posts_share_the_haulers_evenly()


## Haulers are born at the Hearth: a Storehouse's workshops would never be served if they only waited there.
## (Found by the pacing bot after growth needed steady food: 26 haulers idled at other depots while three
## Grindstones by a Storehouse stood starved of grain.)
func test_haulers_wait_at_every_depot_with_work() -> void:
	var s: Sim = t.fresh()
	t.give(s, 200)
	for id in ["storehouse", "fire", "haulers"]:
		s.tech_tree.researched[id] = true
	var camp := s.world.camp_pos
	var far := camp + Vector2i(8 if camp.x < 14 else -8, 0)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			s.world.set_tile(far + Vector2i(dx, dy), "grass")
	s.pathing.build()
	t.check(s.place("storehouse", far), "a Storehouse far from the Hearth")
	t.check(s.place("charcoal_pit", far + Vector2i(1, 0)), "a Charcoal Pit right beside it")
	t.check(
		Roads.linked(s, s.town.buildings[s.town.building_at[far + Vector2i(1, 0)]]), "which it serves without a road"
	)
	s.people.found(8)
	var before: int = s.economy.inv["charcoal"]
	for i in 600:
		s.tick(0.1)
	t.check(s.economy.inv["charcoal"] > before, "haulers reach the Storehouse's pit and it makes charcoal")
	var there := 0
	for k in s.people.kith:
		if k["job"] == "haul" and Vector2(k["pos"]).distance_to(Vector2(far)) < 3.0:
			there += 1
	t.check(there >= 1, "and some of the haulers wait at the Storehouse (%d of %d)" % [there, s.people.kith.size()])
	t.check(Roads.posts(s) == [far], "the Hearth has nothing linked to it, so only the Storehouse is a post")
	t.check(s.place("charcoal_pit", camp + Vector2i(1, 0)), "a second pit right beside the Hearth")
	t.check(Roads.posts(s) == [camp, far], "now the Hearth is a post too, in depot order")
	for i in 600:
		s.tick(0.1)
	var at_hearth := 0
	var at_store := 0
	for k in s.people.kith:
		if k["job"] == "haul" and k["task"].is_empty():
			at_hearth += 1 if Vector2(k["pos"]).distance_to(Vector2(camp)) < 3.0 else 0
			at_store += 1 if Vector2(k["pos"]).distance_to(Vector2(far)) < 3.0 else 0
	t.check(at_hearth >= 1 and at_store >= 1, "haulers wait at both (%d and %d)" % [at_hearth, at_store])


## Found by the pacing bot after the project owner's playtest changes shifted its timeline: on one map 1 of 45 haulers was hashed onto the
## Storehouse that served the Smelters, and the Smelters stood starved for an hour. Idle haulers now take the posts in
## turn by the order they were born in, so no post is left with a handful while another has dozens.
func test_the_posts_share_the_haulers_evenly() -> void:
	var s: Sim = t.fresh()
	t.give(s, 200)
	for id in ["storehouse", "fire", "haulers"]:
		s.tech_tree.researched[id] = true
	var camp := s.world.camp_pos
	var far := camp + Vector2i(8 if camp.x < 14 else -8, 0)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			s.world.set_tile(far + Vector2i(dx, dy), "grass")
	s.pathing.build()
	t.check(s.place("storehouse", far) and s.place("charcoal_pit", far + Vector2i(1, 0)), "a pit by a far Storehouse")
	t.check(s.place("charcoal_pit", camp + Vector2i(1, 0)), "and one by the Hearth")
	s.people.found(30)
	for i in 1500:
		s.tick(0.1)
	var counts := [0, 0]
	for k in s.people.kith:
		if k["job"] == "haul" and k["task"].is_empty():
			counts[0] += 1 if Vector2(k["pos"]).distance_to(Vector2(camp)) < 3.0 else 0
			counts[1] += 1 if Vector2(k["pos"]).distance_to(Vector2(far)) < 3.0 else 0
	t.check(counts[0] >= 8 and counts[1] >= 8, "idle haulers wait at both posts, not just one (%s)" % [counts])
	t.check(absi(counts[0] - counts[1]) <= 4, "in nearly equal numbers (%s)" % [counts])
	var born := Sim.new()
	born.generate(1)
	born.people.births = 0
	born.people.found(36)
	var posts := {}
	for k in born.people.kith:
		var post: int = Haulers.birth_order(k["name"]) % 9
		posts[post] = posts.get(post, 0) + 1
	t.check(
		posts.size() == 9 and posts.values().all(func(n): return n == 4), "36 Kith over 9 posts: 4 each (%s)" % [posts]
	)
