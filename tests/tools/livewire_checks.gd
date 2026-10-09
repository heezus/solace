extends RefCounted
## Livewire's part of the layout pass (tests/tools/layout_pass.gd), kept apart so that file stays under the line limit. Once the
## bot has made its Bronze the pass sets the state to Livewire by hand (the card put away, the three stage 1 techs learned),
## and this walks the new HUD: the fifth research tab and its whole board, the build card of each new building on its own tab,
## the Order Board's card with three orders written, a Power Pole's card, and Wire in the third row of chips.
## Run from the pass with step(layout, frames since the Bronze); `layout` is the pass script (its problems, _report...).

const Data = preload("res://scripts/data.gd")
const Rules = preload("res://scripts/rules.gd")
const HudChecks = preload("res://tests/tools/hud_checks.gd")

const START := 1  # frames after the Bronze when the state is set; the checks follow
const END := 32  # and the pass may end after this
## The four new buildings, each on a tab of its own, in the order they are checked.
const CARDS := ["power_pole", "generator", "wire_mill", "order_board"]


## One frame of the walk: `n` frames since the bot's Bronze.
static func step(layout, n: int) -> void:
	var main: Node = layout.main
	match n:
		START:
			layout.frozen = true
			enter(main)
		START + 2:
			layout._report(board(main, "at 1280x800"))
			layout._report(HudChecks.board_fit(main, "the Livewire board at 1280x800"))
			layout._check_min_text("with the Livewire board open")
			layout._shot("tech_board_livewire")
			main.tech_panel.visible = false
		START + 4, START + 8, START + 12, START + 16:
			main.bottom_bar.show_tab_of(CARDS[floori((n - START - 4) / 4.0)])
			main.ui_refresh = 0.0
		START + 5, START + 9, START + 13, START + 17:
			var type: String = CARDS[floori((n - START - 5) / 4.0)]
			layout._report(card(main, type))
			layout._check_build_cards("on the %s tab" % Data.BUILDINGS[type]["name"])
		START + 20:
			var at := put_board(main)
			layout._report([] if at.x >= 0 else ["no room for an Order Board by the Hearth"])
			main.building_panel.select(at)
			main.ui_refresh = 0.0
		START + 22:
			layout._check_card_is_docked("the Order Board's card")
			layout._check_fit("with the Order Board's card open")
			layout._report(orders(main))
			layout._check_min_text("with the Order Board's card open")
			layout._shot("order_board_card")
		START + 24:
			var pole := put_pole(main)
			main.building_panel.select(pole)
			main.ui_refresh = 0.0
		START + 26:
			layout._check_card_is_docked("a Power Pole's card")
			layout._check_fit("with a Power Pole's card open")
			if not main.building_panel.parts["net"].visible:
				layout.problems.append("a Power Pole's card has no line about its net")
			main.building_panel.select(Vector2i(-1, -1))
			layout._report(HudChecks.third_row(main, "with Wire in the row"))
			layout._report(wire_chip(main))
		START + 28:
			layout._check_top_bar_text("in Livewire")
			layout._report(goals(main))


## The state a Livewire town would be in when the Wires Hum card is put away, set by hand.
static func enter(main: Node) -> void:
	var s = main.state
	for tech in ["blast_furnace", "steel", "rails", "shard_boiler", "bloom_sampling", "livewire", "boiler"]:
		s.tech_tree.researched[tech] = true
	for tech in ["power_poles", "order_board", "generator"]:
		s.tech_tree.researched[tech] = true
	for event in [Data.IRONFALL_EVENT, Data.LIVEWIRE_EVENT, Data.LIVEWIRE_BEGUN]:
		if not s.story.has_event(event):
			s.story.events.append(event)  # quietly: the card and the toast are not what is under test
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
		s.economy.inv[id] = maxi(s.economy.inv.get(id, 0), 300)
	main.tech_panel.era_chosen = false
	main.tech_panel.view_chosen = false
	main.tech_panel._pick_view("all")
	main.tech_panel.visible = true
	main.ui_refresh = 0.0


## The fifth tab is open and chosen, and the board shows all fourteen cards, the eleven of later stages locked.
static func board(main: Node, when: String) -> Array:
	var problems: Array = []
	var panel = main.tech_panel
	if not panel.era_buttons.has(5) or panel.era_buttons[5].disabled:
		return ["%s: the Livewire tab isn't open" % when]
	if panel.board.era != 5 or not panel.era_buttons[5].button_pressed:
		problems.append("%s: the research board didn't open on the Livewire tab" % when)
	var tab: Control = panel.era_buttons[5]
	if tab.get_global_rect().size.x + 1.0 < tab.get_minimum_size().x:
		problems.append("%s: the Livewire tab is cut off" % when)
	if not Rect2(Vector2.ZERO, main.get_viewport_rect().size).encloses(panel.get_global_rect()):
		problems.append("%s: the research board runs off the window (%s)" % [when, panel.get_global_rect()])
	for tech in Rules.era_techs(5):
		if not panel.board.shows(tech):
			problems.append("%s: %s has no card on the Livewire board" % [when, tech])
		if Rules.tech_enabled(tech) != (int(Data.TECHS[tech]["stage"]) == 1):
			problems.append("%s: %s is %s" % [when, tech, "open" if Rules.tech_enabled(tech) else "locked"])
	return problems


## The build card of a new building shows on its tab, the size of the others and inside the bar's height. The row of cards scrolls
## sideways (a long tab runs past the window by design), so only the height and the size are held to the bar.
static func card(main: Node, type: String) -> Array:
	var bar: Control = main.bottom_bar
	var box: Control = bar.build_buttons[type]["button"]
	if bar.tab != bar.tab_of(type) or not box.is_visible_in_tree():
		return ["the %s card isn't showing on its %s tab" % [type, bar.tab_of(type)]]
	var r: Rect2 = box.get_global_rect()
	var problems: Array = []
	if r.position.y < bar.get_global_rect().position.y or r.end.y > bar.get_global_rect().end.y:
		problems.append("the %s card (%s) runs out of the bottom bar's height" % [type, r])
	if box.size.x < bar.BUTTON.x or box.size.y < bar.BUTTON.y:
		problems.append("the %s card is %s, under the usual %s" % [type, box.size, bar.BUTTON])
	return problems


## A Board built by the Hearth with three orders written, so its card is as tall as it gets. Returns its tile, (-1, -1) for none.
static func put_board(main: Node) -> Vector2i:
	var s = main.state
	var at := spot(main, "order_board")
	if at.x < 0:
		return at
	s.place("order_board", at)
	var lw = s.livewire
	for i in 3:
		lw.add(s)
		if i == 1:
			lw.cycle_verb(i)  # one Bring first among the Pauses
		lw.cycle_target(s, i)
		lw.cycle_item(s, i)
		lw.step_number(i, 1)
	return at


## A Power Pole beside the Hearth, joined to a second so it has a net to describe. Returns its tile.
static func put_pole(main: Node) -> Vector2i:
	var s = main.state
	var first := spot(main, "power_pole")
	s.place("power_pole", first)
	var second := spot(main, "power_pole")
	s.place("power_pole", second)
	s.livewire.tick(s, 0.0)
	return first


## The first free tile near the Hearth that takes `type`, (-1, -1) for none.
static func spot(main: Node, type: String) -> Vector2i:
	var s = main.state
	for r in range(2, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and s.town.placement_error(type, p) == "":
					return p
	return Vector2i(-1, -1)


## The Board's card: each order a card of its own, every button whole and inside the side panel, the text at least 14 px.
static func orders(main: Node) -> Array:
	var problems: Array = []
	var panel = main.building_panel.parts["orders"]
	if not panel.visible:
		return ["the Order Board's card shows no orders"]
	var side: Rect2 = main.side_panel.get_global_rect()
	var count := 0
	for node in HudChecks._all(panel):
		if node is Button and node.is_visible_in_tree():
			count += 1
			var r: Rect2 = node.get_global_rect()
			if r.position.x < side.position.x - 0.5 or r.end.x > side.end.x + 0.5:
				problems.append("the order button '%s' (%s) runs out of the side panel (%s)" % [node.text, r, side])
			if node.get_theme_font_size("font_size") < 14 or r.size.y < 20.0:
				problems.append("the order button '%s' is too small (%s)" % [node.text, r.size])
			if node.text != "" and node.get_minimum_size().x > r.size.x + 1.0:
				problems.append("the order button '%s' is cut off" % node.text)
	if count < 3 * 7:
		problems.append("the Board's card has %d buttons for three orders (want at least 21)" % count)
	return problems


## Wire has its chip, a plain one like its row's, and nothing in the row is cut off.
static func wire_chip(main: Node) -> Array:
	var tb = main.top_bar
	if not tb.chips.has("wire") or not tb.chips["wire"]["box"].is_visible_in_tree():
		return ["the Wire chip isn't showing in the top bar"]
	return HudChecks.chip_fit(main, "with Wire showing")


## The Goals list in the new era: its header counts the Livewire goals and the first line is the first of them.
static func goals(main: Node) -> Array:
	var side = main.side_panel
	main.ui_refresh = 0.0
	var header: String = side.goal_header.text
	var want: String = Data.GOALS_HEADER_ERA5 % [main.state.story.done_count(), Data.GOALS_ERA5.size()]
	if header != want:
		return ["the Goals header says '%s', not '%s'" % [header, want]]
	return []
