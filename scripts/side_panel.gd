extends PanelContainer
## The right-hand panel: the Goals checklist on top and, under "Info", the one home for details: the selected
## building's card (scripts/building_panel.gd, with an x to close it) above whatever the mouse is over.
## Nothing floats over the map, and a building's details are never shown twice.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const SkyView = preload("res://scripts/sky_view.gd")

const GOAL_COLOR: Color = Ui.HIGHLIGHT
const GOALS_SHOWN := 2

var goal_header: Label
var goal_labels: Array = []
var info_scroll: ScrollContainer
var info_label: Label
var building_panel: BuildingPanel
var sky_view: SkyView  # the Wanderer's window, shown once Sky Watch has named it
var wrap_width := 260.0


## The panel runs from the top bar to the bottom bar with one 3 px `ui-line` rule against the map.
static func _style() -> StyleBoxFlat:
	var s := Ui.bar_style(Ui.PANEL, true)
	s.border_width_bottom = 0
	s.border_width_left = 3
	s.set_content_margin_all(12)
	return s


func setup(game: Sim, width: float) -> void:
	wrap_width = width - 30.0
	add_theme_stylebox_override("panel", _style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	goal_header = Ui.label("Goals", 18)
	goal_header.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(goal_header)
	for i in GOALS_SHOWN:
		var g := Ui.label("", 14)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD
		g.custom_minimum_size = Vector2(wrap_width, 0)
		v.add_child(g)
		goal_labels.append(g)
	sky_view = SkyView.new()
	v.add_child(sky_view)
	sky_view.setup(game, wrap_width)
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
	# Collect and Pause sit under the scrolling area, so a tall card never pushes them off the panel.
	var buttons: Control = building_panel.parts["buttons"]
	buttons.get_parent().remove_child(buttons)
	v.add_child(buttons)
	buttons.visible = building_panel.visible
	info_label = Ui.label("", 14)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.custom_minimum_size = Vector2(60, 0)
	inner.add_child(info_label)


## The checklist: only the current goal (in gold) and the one after it (dim). The done ones are behind the count in the
## header ("Goals 9/22", or "Dawn goals 3/9" in the second era; hover it to list them), so a long goal never pushes the
## current one down. Both lines stay up while a building's card is open (the card scrolls), so the list never changes
## height as cards come and go.
func refresh_goals(s: Sim) -> void:
	var list := s.story.goal_list()
	var cur := s.story.current_goal()
	var total := list.size()
	var era_two := list == Data.GOALS_ERA2
	goal_header.text = (Data.GOALS_HEADER_ERA2 if era_two else Data.GOALS_HEADER) % [s.story.done_count(), total]
	var done: Array = []
	for g in list:
		if s.story.goals_done.has(g["id"]):
			done.append("Done: " + g["text"])
	goal_header.tooltip_text = "\n".join(done)
	for i in goal_labels.size():
		var gi := cur + i
		var l: Label = goal_labels[i]
		l.visible = gi < total
		if not l.visible:
			continue
		l.text = ("> " if i == 0 else "  ") + list[gi]["text"]
		l.add_theme_color_override("font_color", GOAL_COLOR if i == 0 else Ui.TEXT_DIM)
	if cur >= total:
		goal_labels[0].visible = true
		goal_labels[0].text = Data.GOALS_ALL_DONE


## Show `text` under the card; a card that doesn't fit scrolls (the bar only shows when it must).
func show_info(text: String) -> void:
	info_label.text = text
	info_label.visible = text != ""
	info_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if building_panel.visible else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	)
