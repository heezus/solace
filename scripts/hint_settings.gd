extends RefCounted
## The first-time hints on/off switch (the pause menu's "Hints"). Kept in a small file of its own under user://, apart from the run
## save and the profile (which holds which hints were shown), so a loaded game or a new run keeps the choice. On until the player
## turns it off. Static, and modelled on CutsceneSettings: `on()` reads the file once and `set_on` writes it.

static var path := "user://hints.cfg"
static var _on = null  # null until the file has been read


## True when the hints are switched on (the default).
static func on() -> bool:
	if _on == null:
		var cfg := ConfigFile.new()
		_on = cfg.load(path) != OK or bool(cfg.get_value("hints", "on", true))
	return _on


## Switch the hints on or off and keep the choice.
static func set_on(value: bool) -> void:
	_on = value
	var cfg := ConfigFile.new()
	cfg.set_value("hints", "on", value)
	cfg.save(path)


## Forget what was read, so the next `on()` reads the file again.
static func reset() -> void:
	_on = null
