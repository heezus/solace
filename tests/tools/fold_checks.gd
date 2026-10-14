extends RefCounted
## The layout pass's checks of the message log and of the folding side panel (scripts/hud_fold.gd), kept apart so layout_pass.gd stays
## under the line limit. `layout` is the pass script (its problems, main, _labels).

const Data = preload("res://scripts/data.gd")


## The message log opened, has lines, stays inside the window and shows the newest message.
static func log_opens(layout) -> void:
	var main: Node = layout.main
	layout.hud_checks += 1
	if not main.msg_log.visible:
		layout.problems.append("the message log didn't open")
		return
	if main.msg_log.list.get_child_count() < 1:
		layout.problems.append("the message log is empty")
	if not Rect2(Vector2.ZERO, main.get_viewport_rect().size).encloses(main.msg_log.get_global_rect()):
		layout.problems.append("the message log runs off the window (%s)" % main.msg_log.get_global_rect())
	var found := false
	for l in layout._labels(main.msg_log):
		found = found or l.text == "Discovered a thing"
	if not found:
		layout.problems.append("the newest message isn't in the log")


## Folded, the side panel is gone, the map takes the whole width and the goal chip sits inside the map's top right, saying the
## goal; unfolded, the panel and the 1016 px map are back.
static func fold(layout) -> void:
	var main: Node = layout.main
	layout.hud_checks += 1
	var width: float = main.get_viewport_rect().size.x
	var cam: Vector2 = main.cam  # a wider view clamps the camera: put it back, so the pass sees the map where it was
	main.hud.folded = true
	main._layout()
	main._refresh_ui()
	if main.side_panel.visible or main.view.size.x != width:
		layout.problems.append("folded, the side panel is still up or the map isn't the whole width (%s)" % main.view)
	var chip: Button = main.hud.chip
	var chip_rect := Rect2(chip.position, chip.size)
	if not chip.visible or not main.view.encloses(chip_rect) or not chip.text.begins_with("Goal: "):
		layout.problems.append("the goal chip is missing, off the map or empty ('%s' at %s)" % [chip.text, chip_rect])
	for list in [Data.GOALS, Data.GOALS_ERA2, Data.GOALS_ERA3, Data.GOALS_ERA4, Data.GOALS_ERA5]:
		for g in list:
			main.hud.refresh("> " + g["text"])
			if not main.hud._fits(chip.text):
				layout.problems.append("the goal chip needs more than two lines for '%s'" % chip.text)
	main.hud.folded = false
	main.cam = cam
	main._layout()
	if not main.side_panel.visible or chip.visible or main.view.size.x != width - main.SIDE_W:
		layout.problems.append("unfolded, the side panel or the map width didn't come back (%s)" % main.view)
