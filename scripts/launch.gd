extends RefCounted
## How the next game starts, handed from the title screen (or the pause menu's Load) to the game scene: a new map, or the
## run save. Read once by the game (`take_load`), so a reloaded scene starts fresh unless it is asked to load again.

static var _load_save := false


## Ask the next game to start from the run save.
static func ask_to_load() -> void:
	_load_save = true


## True once if the title screen asked for the run save; the flag is cleared.
static func take_load() -> bool:
	var asked := _load_save
	_load_save = false
	return asked
