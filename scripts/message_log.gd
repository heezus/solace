extends PanelContainer
## The message log: the last messages (scripts/messages.gd), newest first with the time each came, so a toast that
## went by too fast is never lost. Opened with L or the Messages button in the top bar; Esc, L or the x closes it.

const Ui = preload("res://scripts/ui.gd")
const Messages = preload("res://scripts/messages.gd")

const W := 420.0
const H := 300.0
const SHOWN := 30  # entries listed

var messages: Messages
var list: VBoxContainer
var empty_note: Label


func setup(queue: Messages) -> void:
	messages = queue
	visible = false
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	var title := Ui.label("Messages", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Ui.button("x")
	close.custom_minimum_size = Vector2(26, 26)
	close.tooltip_text = "Close (L)"
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	queue.changed.connect(refresh)
	visibility_changed.connect(refresh)


func toggle() -> void:
	visible = not visible


## Rebuild the list from the log (only while it's open).
func refresh() -> void:
	if not visible:
		return
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var entries := messages.recent(SHOWN)
	if entries.is_empty():
		var note := Ui.label("Nothing yet.", 13)
		note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		list.add_child(note)
	for e in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var at := Ui.label(Messages.clock_text(e["at"]), 12)
		at.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		at.custom_minimum_size.x = 38.0
		at.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(at)
		var text := Ui.label(Messages.entry_text(e), 13)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.x = 200.0
		if e["sticky"]:
			text.add_theme_color_override("font_color", Ui.HIGHLIGHT)
		row.add_child(text)
		list.add_child(row)
