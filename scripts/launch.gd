extends RefCounted
## How the next game starts, handed from the title screen (or the pause menu's Load) to the game scene: a new map, a save
## slot, or a stage start (a run dump built by DevStarts). Read once by the game (`start_into`), so a reloaded scene starts
## fresh unless it is asked again.

const RunSave = preload("res://scripts/run_save.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")

static var _slot := 0  # the save slot to start from, 0 for none
static var _stage: Dictionary = {}  # the run dump of a stage start, {} for none


## Ask the next game to start from save slot `slot`.
static func ask_to_load(slot: int) -> void:
	_slot = slot


## The slot the title screen asked for, once (0 when it did not); the ask is cleared.
static func take_load() -> int:
	var asked := _slot
	_slot = 0
	return asked


## Ask the next game to begin a new run from `dump`, a stage start (DevStarts.build, then RunSave.dump).
static func ask_stage(dump: Dictionary) -> void:
	_stage = dump


## The stage start the title screen asked for, once ({} when it did not); the ask is cleared.
static func take_stage() -> Dictionary:
	var asked := _stage
	_stage = {}
	return asked


## Put what was asked for into `s`: the stage start, else the save slot. False, with `s` untouched, when nothing was asked
## or what was asked could not be read (the game then starts on a new map).
static func start_into(s, dir := SaveSlots.DIR) -> bool:
	var stage := take_stage()
	var slot := take_load()
	if not stage.is_empty():
		return RunSave.restore(s, stage)
	return slot > 0 and SaveSlots.load_into(s, slot, dir)
