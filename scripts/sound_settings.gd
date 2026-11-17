extends RefCounted
## The sound switches: a master volume, one for effects, one for the valley's ambience, and a mute. Kept in a small file of its
## own under user:// (apart from the run save and the profile, like the hints switch), so a loaded game or a new run keeps the
## player's choice. Static: each getter reads the file once and each setter writes it. `apply` puts them on the audio buses.

const MASTER_BUS := "Master"
const SFX_BUS := "Sfx"
const AMBIENCE_BUS := "Ambience"
const MUTE_LABEL := "Mute sound"
const MUTE_HELP := "Silences everything. Your volume levels are kept."
const MASTER_LABEL := "Volume"
const SFX_LABEL := "Effects"
const AMBIENCE_LABEL := "Ambience"
const DEFAULT_MASTER := 0.8
const DEFAULT_SFX := 1.0
const DEFAULT_AMBIENCE := 1.0

static var path := "user://sound.cfg"
static var _loaded := false
static var _values := {"master": DEFAULT_MASTER, "sfx": DEFAULT_SFX, "ambience": DEFAULT_AMBIENCE, "muted": false}


static func master() -> float:
	return _read("master")


static func sfx() -> float:
	return _read("sfx")


static func ambience() -> float:
	return _read("ambience")


static func muted() -> bool:
	return bool(_read("muted"))


## Set the master volume (0 to 1), keep it, and put it on the buses.
static func set_master(v: float) -> void:
	_write("master", clampf(v, 0.0, 1.0))


static func set_sfx(v: float) -> void:
	_write("sfx", clampf(v, 0.0, 1.0))


static func set_ambience(v: float) -> void:
	_write("ambience", clampf(v, 0.0, 1.0))


static func set_muted(on: bool) -> void:
	_write("muted", on)


## A slider's 0 to 1 as decibels: the slider is a straight line in loudness, so half way is about -6 dB, and 0 is silent.
static func db_of(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


## Make sure the Sfx and Ambience buses exist (they send to Master), then set every bus from the switches.
static func apply() -> void:
	for bus in [SFX_BUS, AMBIENCE_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, MASTER_BUS)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), db_of(master()))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), muted())
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), db_of(sfx()))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(AMBIENCE_BUS), db_of(ambience()))


## Forget what was read, so the next getter reads the file again (tests point `path` elsewhere and call this).
static func reset() -> void:
	_loaded = false
	_values = {"master": DEFAULT_MASTER, "sfx": DEFAULT_SFX, "ambience": DEFAULT_AMBIENCE, "muted": false}


static func _read(key: String):
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			for k in _values:
				_values[k] = cfg.get_value("sound", k, _values[k])
	return _values[key]


static func _write(key: String, value) -> void:
	_read(key)  # read the file first, so the other switches are kept
	_values[key] = value
	var cfg := ConfigFile.new()
	for k in _values:
		cfg.set_value("sound", k, _values[k])
	cfg.save(path)
	apply()
