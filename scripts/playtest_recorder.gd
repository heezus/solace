extends Node
## The playtest log's eyes on the screen (scripts/playtest_log.gd): a child of the game scene that writes what only the interface knows
## (clicks, the building card opening, the pause menu, cutscenes watched or skipped, the Chronicle, the endings card and the details
## of each ending the player opened, two quiet minutes). It reads the panels once a frame and never writes to the game. Attached only
## when the Sim has a log (`state.seasons.watcher`), so it is off with the log.

const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const Data = preload("res://scripts/data.gd")

const QUIET_SECONDS := 120.0  # real seconds without a click or key, in play, before a `quiet` line

var _main  # the game scene (scripts/main.gd)
var _s  # its Sim
var _real := 0.0
var _last_input := 0.0
var _quiet_sent := false
var _panel := Vector2i(-1, -1)
var _menu_up := false
var _book_page := ""
var _endings_at := -1.0
var _confirm_up := false


## Hang a recorder on the game scene (`layer` is its CanvasLayer). Null when the log is off.
static func attach(layer: Node, main):
	if main.state.seasons.watcher == null:
		return null
	var r = new()
	layer.add_child(r)
	r.setup(layer, main)
	return r


func setup(layer: Node, main) -> void:
	_main = main
	_s = main.state
	for c in layer.get_children():
		if c.get_script() == CutscenePlayer:
			c.finished.connect(_on_cutscene.bind(c))
	main.game_menu.endings.chosen.connect(func(id: String): _s.seasons.watcher.act(_s, "ending", id, true))


func _process(delta: float) -> void:
	_real += delta
	var journal = _s.seasons.watcher
	var sel: Dictionary = _main.building_panel.selected()
	var at: Vector2i = sel["pos"] if not sel.is_empty() else Vector2i(-1, -1)
	if at != _panel and at.x >= 0:
		journal.event(_s, "panel", {"what": sel["type"], "pos": [at.x, at.y]})
	_panel = at
	var menu: bool = _main.game_menu.menu.visible
	if menu != _menu_up:
		journal.event(_s, "menu", {"open": menu})
		_menu_up = menu
	var book = _main.game_menu.book
	var page: String = book.page if book.visible else ""
	if page != _book_page and page != "":
		journal.event(_s, "chronicle", {"page": page})
	_book_page = page
	var endings: bool = _main.game_menu.endings.visible
	if endings and _endings_at < 0.0:
		_endings_at = _real
		journal.event(_s, "endings", {"open": true})
	elif not endings and _endings_at >= 0.0:
		journal.event(_s, "endings", {"open": false, "secs": snappedf(_real - _endings_at, 0.1)})
		_endings_at = -1.0
	var confirm: bool = _main.game_menu.confirm.visible
	if confirm and not _confirm_up:
		var said: String = _main.game_menu.confirm._text.text
		for id in ["exodus", "cataclysm", "loop", "seal", "heal", "leave"]:
			if Data.ENDINGS.has(id) and said == Data.ENDINGS[id]["end"]:
				journal.event(_s, "detail", {"ending": id})
	_confirm_up = confirm
	var calm: bool = not _main.paused and not menu and not endings
	if calm and not _quiet_sent and _real - _last_input >= QUIET_SECONDS:
		_quiet_sent = true
		journal.event(_s, "quiet", {"secs": snappedf(_real - _last_input, 1.0)})


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		_last_input = _real
		_quiet_sent = false
		if event is InputEventMouseButton:
			_s.seasons.watcher.event(_s, "click", {"btn": event.button_index})


func _exit_tree() -> void:
	if _s != null and _s.seasons.watcher != null:
		_s.seasons.watcher.end(_s, "left")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _s != null and _s.seasons.watcher != null:
		_s.seasons.watcher.end(_s, "closed")


func _on_cutscene(id: String, skipped: bool, player) -> void:
	_s.seasons.watcher.event(_s, "cutscene", {"id": id, "skipped": skipped, "secs": snappedf(player.total_time, 0.1)})
