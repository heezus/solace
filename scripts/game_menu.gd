extends Control
## The game's menu: the pause menu card and what its buttons do. Resume puts it away; Save game opens the slot screen to
## pick a slot and writes the run there; Load game opens it to pick a save (or a stage start, which begins a new run) and
## starts the game scene again from it, so nothing of this run is left behind; Quit to title goes back to the first screen.
## "Choose an ending" (the entry here and the Skyward card's own button, through `ask_set_out`) opens the ending card
## (scripts/ending_card.gd): the Exodus, the Cataclysm or the Time loop, as far as the Lumen lean opens them. The row chosen asks
## "Leave this land?" on a confirm card (scripts/confirm_card.gd) that says how that ending ends, and a yes sets out. Forget past
## runs asks first on the same card.
## The owner (scripts/main.gd) pauses while it is open and resumes when it closes, through `paused_changed`.
## Signal: paused_changed(on) fires when the menu opens (true) or closes (false).

signal paused_changed(on: bool)

const ChronicleBook = preload("res://scripts/chronicle_book.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const Data = preload("res://scripts/data.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const SlotScreen = preload("res://scripts/slot_screen.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const Launch = preload("res://scripts/launch.gd")
const ConfirmCard = preload("res://scripts/confirm_card.gd")
const EndingCard = preload("res://scripts/ending_card.gd")
const Endings = preload("res://scripts/endings.gd")
const Profile = preload("res://scripts/profile.gd")

const TITLE_SCENE := "res://scenes/title.tscn"

var state  # the Sim being played
var slot_dir := SaveSlots.DIR
var menu: PauseMenu
var slots: SlotScreen
var confirm: ConfirmCard
var endings: EndingCard
var book: ChronicleBook
var profile_path := Profile.PATH


## `era_card` is the end-of-era card (scripts/era_card.gd): its "Set out" button asks here (null in a test without one).
func setup(game, era_card = null) -> void:
	state = game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = PauseMenu.new()
	add_child(menu)
	menu.setup()
	slots = SlotScreen.new()
	slots.dir = slot_dir
	add_child(slots)
	slots.setup()
	confirm = ConfirmCard.new()
	add_child(confirm)
	confirm.setup()
	endings = EndingCard.new()
	add_child(endings)
	endings.setup()
	endings.chosen.connect(ask_confirm)
	book = ChronicleBook.new()
	add_child(book)
	book.setup()
	menu.chronicle_pressed.connect(open_chronicle)
	menu.set_out_pressed.connect(ask_set_out)
	if era_card != null:
		era_card.set_out_pressed.connect(ask_set_out)
	menu.forget_pressed.connect(ask_forget)
	menu.resumed.connect(func(): paused_changed.emit(false))
	menu.save_pressed.connect(func(): slots.open("save"))
	menu.load_pressed.connect(func(): slots.open("load"))
	menu.quit_pressed.connect(quit_to_title)
	slots.slot_picked.connect(_on_slot)
	slots.start_picked.connect(start_stage)


## Lay the menu over `area` (the map view), as the cards do.
func place(area: Rect2) -> void:
	menu.place(area)
	slots.place(area)
	endings.place(area)
	confirm.place(area)
	# The Chronicle is a page of its own: over the whole window (the dock and bars too, dimmed), as on the title screen, so its
	# columns never run over the goals panel.
	book.place(Rect2(Vector2.ZERO, get_viewport_rect().size) if is_inside_tree() else area)


func is_open() -> bool:
	return menu.visible or confirm.visible or endings.visible or book.visible


## Put the menu up and pause the game behind it. Set out is open once Skyward stands.
func open() -> void:
	menu.open()
	menu.set_out_button.disabled = not set_out_open()
	menu.set_out_button.tooltip_text = Data.ENDINGS["choose_tip"]
	paused_changed.emit(true)


## Esc: put the question away if one is up, else the ending card, else the slot screen if it is up, else the menu and let the game go on.
func close() -> void:
	if confirm.visible:
		confirm.cancel()
	elif endings.visible:
		endings.cancel()
	elif book.visible:
		book.close()
	elif slots.visible:
		slots.close()
	else:
		menu.resume()


func _on_slot(slot: int) -> void:
	if slots.mode == "save":
		save_game(slot)
		slots.close()
	else:
		load_game(slot)


## Save game: the whole run into slot `slot`.
func save_game(slot: int) -> bool:
	var ok := SaveSlots.save(state, slot, slot_dir)
	menu.say(Data.SAVE_SLOT_DONE % slot if ok else Data.SAVE_FAILED, ok)
	return ok


## Load game: start the game scene again from slot `slot`. False, with a word on the menu, when it holds nothing.
func load_game(slot: int) -> bool:
	if SaveSlots.read(slot, slot_dir).is_empty():
		menu.say(Data.LOAD_BAD_SLOT, false)
		slots.close()
		return false
	Launch.ask_to_load(slot)
	get_tree().reload_current_scene()
	return true


## Begin a new run from a stage start (`dump`, built by the slot screen): the game scene starts again from it.
func start_stage(dump: Dictionary) -> void:
	Launch.ask_stage(dump)
	get_tree().reload_current_scene()


## Quit to title: anything not saved is lost, as the menu says.
func quit_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


## True once the telling can end: Skyward stands in the first telling, the Skyreach in the second and later ones.
func set_out_open() -> bool:
	return state.story.events.has(Data.SKYWARD_EVENT if state.carry.is_first() else Data.SKYREACH["done"])


## Choose an ending: the ending card goes up for this run's number and the Lumen lean the Starfall era ended with.
func ask_set_out() -> void:
	if set_out_open():
		endings.open(state.carry.exodus + 1, state.starfall.lean)


## The row `ending` was chosen: ask "Leave this land?" in the words of how that ending ends. A yes sets out, a no changes nothing.
func ask_confirm(ending: String) -> void:
	if set_out_open() and Endings.is_open(ending, state.starfall.lean):
		confirm.ask(
			Data.ENDINGS[ending]["end"],
			Data.ENDINGS["confirm_yes"],
			Data.ENDINGS["confirm_no"],
			func(): set_out(ending)
		)


## Set out with `ending` ("exodus", "cataclysm" or "loop"): the ending is a story moment, the run is folded into the profile with
## its carry banked, and a new run begins (the scene starts again; the new run reads the carry from the profile). False, and
## the Kith stay, when Skyward does not stand yet, the Lumen lean shuts that ending or the profile could not be written (the
## carry would be lost).
func set_out(ending := "exodus") -> bool:
	if not set_out_open() or not Endings.is_open(ending, state.starfall.lean):
		return false
	state.story.record(Data.ENDINGS[ending]["id"])
	if not Profile.set_out(state, profile_path, ending).saved:
		menu.say(Data.ENDINGS["unsaved"], false)
		return false
	if is_inside_tree():
		_begin_next_run()
	return true


## The Chronicle (scripts/chronicle_book.gd), from the pause menu: every telling that has ended, read from the profile.
func open_chronicle(page := "tellings", after_ending := false) -> void:
	var profile := Profile.new()
	profile.load_file(profile_path)
	book.open(profile, page, after_ending)


## The next run begins by starting the scene again, after the fireside the ending queued (when cutscenes are on) has been told and
## the Chronicle has opened on the telling that just ended.
func _begin_next_run() -> void:
	for player in get_tree().get_nodes_in_group(CutscenePlayer.GROUP):
		if player.fireside_pending():
			player.finished.connect(_fireside_told)
			return
	_chronicle_then_next_run()


func _fireside_told(id: String, _skipped: bool) -> void:
	if id == "fireside":
		_chronicle_then_next_run()


func _chronicle_then_next_run() -> void:
	book.closed.connect(get_tree().reload_current_scene, CONNECT_ONE_SHOT)
	open_chronicle("tellings", true)


## Ask "Forget every past run?": a yes clears the profile, a no changes nothing.
func ask_forget() -> void:
	confirm.ask(Data.EXODUS["forget_confirm"], Data.EXODUS["forget_yes"], Data.EXODUS["forget_no"], forget)


## Forget past runs: the profile is cleared, so the next new game is a first game. The run being played goes on as it was.
func forget() -> bool:
	var ok := Profile.forget(profile_path)
	menu.say(Data.EXODUS["forget_done"] if ok else Data.EXODUS["forget_failed"], ok)
	return ok
