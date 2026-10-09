extends RefCounted
## The cutscene on/off switch (the pause menu's "Cutscenes"). It is kept in a small file of its own under user://, apart from
## the run save and the profile, so a loaded game or a new run keeps the choice. On until the player turns it off. Static,
## and modelled on DebugKeys: `on()` reads the file once and `set_on` writes it.

static var path := "user://cutscenes.cfg"
static var _on = null  # null until the file has been read


## True when cutscenes are switched on (the default).
static func on() -> bool:
	if _on == null:
		var cfg := ConfigFile.new()
		_on = cfg.load(path) != OK or bool(cfg.get_value("cutscenes", "on", true))
	return _on


## Switch cutscenes on or off and keep the choice.
static func set_on(value: bool) -> void:
	_on = value
	var cfg := ConfigFile.new()
	cfg.set_value("cutscenes", "on", value)
	cfg.save(path)


## Forget what was read, so the next `on()` reads the file again.
static func reset() -> void:
	_on = null
