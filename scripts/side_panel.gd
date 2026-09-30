extends PanelContainer
## The right-hand panel: the Goals checklist on top and, under "Info", the one home for details: the selected
## building's card (scripts/building_panel.gd, with an x to close it) above whatever the mouse is over.
## Nothing floats over the map, and a building's details are never shown twice.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")

const GOOD := Color("80ed99")
const GOAL_COLOR := Color("ffd166")
const GOALS_SHOWN := 4

var goal_header: Label
var goal_labels: Array = []
var info_scroll: ScrollContainer
var info_label: Label
var building_panel: BuildingPanel
var wrap_width := 260.0


func setup(game: Sim, width: float) -> void:
	wrap_width = width - 30.0
	add_theme_stylebox_override("panel", Ui.panel_style(Color("264653"), 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	goal_header = Ui.label("Goals", 18)
	v.add_child(goal_header)
	for i in GOALS_SHOWN:
		var g := Ui.label("", 14)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD
		g.custom_minimum_size = Vector2(wrap_width, 0)
		v.add_child(g)
		goal_labels.append(g)
	v.add_child(HSeparator.new())
	v.add_child(Ui.label("Info", 18))
	# The selected building's card, then the text under the mouse. Both clip to the panel, never past its bottom edge.
	info_scroll = ScrollContainer.new()
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	v.add_child(info_scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.add_child(inner)
	building_panel = BuildingPanel.new()
	inner.add_child(building_panel)
	building_panel.setup(game)
	# Collect, Pause and Demolish sit under the scrolling area, so a tall card never pushes them off the panel.
	var buttons: Control = building_panel.parts["buttons"]
	buttons.get_parent().remove_child(buttons)
	v.add_child(buttons)
	buttons.visible = building_panel.visible
	info_label = Ui.label("", 14)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.custom_minimum_size = Vector2(60, 0)
	inner.add_child(info_label)


## The checklist: the current goal in gold, done ones in green, the next few after it. While a building's card is
## open only the current goal shows, so the card has room.
func refresh_goals(s: Sim) -> void:
	var cur := s.story.current_goal()
	goal_header.text = "Goals (%d/%d)" % [mini(cur, Data.GOALS.size()), Data.GOALS.size()]
	for i in goal_labels.size():
		var gi := cur - 1 + i
		var l: Label = goal_labels[i]
		l.visible = gi >= 0 and gi < Data.GOALS.size() and (not building_panel.visible or gi == cur)
		if not l.visible:
			continue
		var done: bool = s.story.goals_done.has(Data.GOALS[gi]["id"])
		l.text = ("Done: " if done else ("> " if gi == cur else "  ")) + Data.GOALS[gi]["text"]
		var col := GOOD if done else (GOAL_COLOR if gi == cur else Color(1, 1, 1, 0.55))
		l.add_theme_color_override("font_color", col)
	if cur >= Data.GOALS.size():
		goal_labels[1].visible = true
		goal_labels[1].text = "All goals done."


## Show `text` under the card; a card that doesn't fit scrolls (the bar only shows when it must).
func show_info(text: String) -> void:
	info_label.text = text
	info_label.visible = text != ""
	info_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if building_panel.visible else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	)
