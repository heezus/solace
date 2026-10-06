extends RefCounted
## PR 1 of the growth batch (design-system/17-needs-and-upgrades.md): buildings stay off the build bar until the tech
## tree has revealed them, the Jobs line counts places and not buildings, road and bridge tiers, copy cost, the hand
## cart and fog scouting. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const CardText = preload("res://scripts/card_text.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_cards_wait_for_the_tech_tree_to_reveal_them()


# --- Hidden until learned ------------------------------------------------------


func test_cards_wait_for_the_tech_tree_to_reveal_them() -> void:
	var s: Sim = t.fresh()
	t.check(CardText.shown(s, "dwelling") and CardText.shown(s, "camp"), "buildings with no tech always show")
	for type in ["cart_shed", "trading_post", "storehouse", "kiln", "road", "water_wheel", "mine"]:
		t.check(not CardText.shown(s, type), "%s stays off the bar before the tree reveals it" % type)
	t.check(not CardText.shown(s, "road"), "the Road waits for Paths & Haulers to show up on the board")
	t.check(not s.tech_tree.tech_visible("haulers"), "(it is not in view at the start)")
	for id in Data.ITEM_ORDER:  # everything has been found: only the research decides what shows
		s.economy.seen[id] = true
	t.check(s.tech_tree.tech_visible("haulers"), "Paths & Haulers is in view once its items were found")
	t.check(CardText.shown(s, "road"), "so the Road card shows, locked")
	t.check(not CardText.shown(s, "cart_shed"), "the Cart Shed still hides: The Wheel needs its own parents in view")
	s.tech_tree.researched["the_wheel"] = true
	t.check(CardText.shown(s, "cart_shed"), "a learned tech always shows its card")
