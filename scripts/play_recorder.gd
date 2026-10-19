extends Node
## The play recorder in the game (design-system/25-playtesting.md): a child of the game scene that hands the PlayLog what the player
## sees and does each frame, shows the three-question card once after each era, and closes the log when the run is left or the
## window closed. It only reads the game; the one thing it asks of it is a pause behind its card. Off when the pause menu's "Play
## log" switch is off, and in a headless run (the tests and the scripted passes), unless a test sets `allow_headless`.

const Data = preload("res://scripts/data.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const PlayAskCard = preload("res://scripts/play_ask_card.gd")
const PlayLog = preload("res://scripts/play_log.gd")
const PlayLogSettings = preload("res://scripts/play_log_settings.gd")

static var allow_headless := false
static var dir := Data.PLAYLOG_DIR

var journal := PlayLog.new()
var ask: PlayAskCard
var _main  # the game scene (scripts/main.gd)
var _asking := ""  # the era being asked about, "" while no card is up
var _asked := {}  # era ids already asked this run
var _banner_was := true  # until the first frame, when the game has set it from the run (a loaded win has had its banner)
var _started := false


## Hang a recorder on the game scene (`layer` is its CanvasLayer). Null when the log is off or this is a headless run.
static func attach(layer: Node, main):
	if not PlayLogSettings.on() or (DisplayServer.get_name() == "headless" and not allow_headless):
		return null
	var r = new()
	layer.add_child(r)
	r.setup(main, layer)
	return r


func setup(main, layer: Node) -> void:
	_main = main
	ask = PlayAskCard.new()
	layer.add_child(ask)
	ask.setup()
	ask.answered.connect(_on_answered)
	main.era_card.closed.connect(_on_era_card_closed)  # after the game's own handler, so the pause set here is the last word
	journal.begin(
		main.state,
		dir,
		Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-"),
		DisplayServer.window_get_size(),
		BuildInfo.line(),
		main.state.seasons.time > 0.0
	)


func _process(delta: float) -> void:
	var s = _main.state
	if not _started:
		_started = true
		_banner_was = _main.banner_shown
	var cards: Array = []
	for pair in [["era", _main.era_card], ["moment", _main.moment_card], ["notice", _main.notice_card]]:
		if pair[1].visible:
			cards.append(pair[0])
	if _main.game_menu.is_open():
		cards.append("menu")
	if ask.visible:
		cards.append("ask")
		ask.place(_main.view)
	journal.note(s, {"speed": _main.speed, "paused": _main.paused, "cards": cards}, delta)
	if _main.banner_shown and not _banner_was:
		_banner_was = true
		_ask_about("stone")  # the stone age ends with a banner, not a card


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		journal.input()


func _exit_tree() -> void:
	journal.end(_main.state, "left")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		journal.end(_main.state, "closed")


func _on_era_card_closed() -> void:
	_ask_about(str(journal._era(_main.state)))  # the era the card ended


## Put the question card up for an era, once, and hold the game behind it.
func _ask_about(era_id: String) -> void:
	if _asked.has(era_id) or ask.visible:
		return
	_asked[era_id] = true
	_asking = era_id
	_main.paused = true
	ask.place(_main.view)
	ask.open()


func _on_answered(answers: Dictionary) -> void:
	journal.era_end(_main.state, _asking, answers)
	_asking = ""
	_main.paused = false
