extends RefCounted
## What plays, and how loudly, so that a busy settlement still sounds calm. Pure rules with no audio in them: the Sound node asks
## `request` for every cue and plays what comes back. A cue is dropped when it repeats too soon (its `gap`), when too many of its
## kind are still sounding (its group's voices), when the whole mix is full, when it is far from the player's view, or when
## the town is so busy that the everyday sounds (work, building, the Bloom) would only be noise. The rest play a little quieter the
## busier it gets. Events that mean something (a goal, a discovery, a warning, an ending) always get through.
##
## A cue's `local` marks one that comes from a tile: it fades with the tile's distance from the middle of the view.

const FULL_TILES := 9.0  # tiles from the middle of the view within which a sound is heard at full strength
const FAR_TILES := 36.0  # beyond this many tiles a sound is not heard at all
const MIN_GAIN := 0.03  # a sound this quiet is not worth a voice
const MAX_VOICES := 10  # sounds sounding at once, whatever they are
const CROWD_WINDOW := 4.0  # seconds over which recent plays are counted
const CALM_PLAYS := 5  # plays in the window before everyday sounds start to give way
const DUCK_PER_PLAY := 1.2  # decibels each play over CALM_PLAYS takes off everyday sounds
const MAX_DUCK := 9.0
const BUSY_PLAYS := 14  # plays in the window above which the everyday sounds are dropped altogether
const GROUP_VOICES := {"build": 4, "work": 4, "bloom": 2, "ui": 3, "event": 3}
const EVERYDAY := ["build", "work", "bloom"]  # the groups that give way to a crowd

## id -> the files (in audio/sfx, without .ogg), the group, a trim in decibels, the seconds before it may play again, and whether
## it comes from a tile.
const CUES := {
	"ui_click": {"files": ["ui_click_1", "ui_click_2"], "group": "ui", "db": -6.0, "gap": 0.04, "local": false},
	"refuse": {"files": ["refuse"], "group": "ui", "db": -3.0, "gap": 0.3, "local": false},
	"card": {"files": ["card"], "group": "event", "db": -3.0, "gap": 0.4, "local": false},
	"place": {"files": ["place_1", "place_2", "place_3"], "group": "build", "db": -2.0, "gap": 0.12, "local": true},
	"demolish": {"files": ["demolish_1", "demolish_2"], "group": "build", "db": -2.0, "gap": 0.15, "local": true},
	"road": {"files": ["road_1", "road_2", "road_3"], "group": "build", "db": -5.0, "gap": 0.1, "local": true},
	"gather_wood":
	{
		"files": ["gather_wood_1", "gather_wood_2", "gather_wood_3"],
		"group": "work",
		"db": -4.0,
		"gap": 0.3,
		"local": true
	},
	"gather_stone":
	{
		"files": ["gather_stone_1", "gather_stone_2", "gather_stone_3"],
		"group": "work",
		"db": -4.0,
		"gap": 0.3,
		"local": true
	},
	"gather_berries":
	{
		"files": ["gather_berries_1", "gather_berries_2", "gather_berries_3"],
		"group": "work",
		"db": -4.0,
		"gap": 0.3,
		"local": true
	},
	"craft": {"files": ["craft_1", "craft_2", "craft_3"], "group": "work", "db": -7.0, "gap": 0.45, "local": true},
	"delivery":
	{"files": ["delivery_1", "delivery_2", "delivery_3"], "group": "work", "db": -10.0, "gap": 0.5, "local": true},
	"born": {"files": ["born"], "group": "event", "db": -4.0, "gap": 1.0, "local": true},
	"research_done": {"files": ["research_done"], "group": "event", "db": -3.0, "gap": 1.0, "local": false},
	"goal_done": {"files": ["goal_done"], "group": "event", "db": -3.0, "gap": 1.0, "local": false},
	"era_bell": {"files": ["era_bell"], "group": "event", "db": -2.0, "gap": 4.0, "local": false},
	"glyph": {"files": ["glyph"], "group": "event", "db": -3.0, "gap": 1.5, "local": false},
	"ending": {"files": ["ending"], "group": "event", "db": -2.0, "gap": 8.0, "local": false},
	"expedition": {"files": ["expedition"], "group": "event", "db": -4.0, "gap": 2.0, "local": true},
	"landfall_warn": {"files": ["landfall_warn"], "group": "event", "db": -3.0, "gap": 3.0, "local": false},
	"seed_fall": {"files": ["seed_fall_1", "seed_fall_2"], "group": "bloom", "db": -2.0, "gap": 0.8, "local": true},
	"bloom_spread":
	{
		"files": ["bloom_spread_1", "bloom_spread_2", "bloom_spread_3"],
		"group": "bloom",
		"db": -8.0,
		"gap": 2.5,
		"local": true
	},
	"bloom_take": {"files": ["bloom_take_1", "bloom_take_2"], "group": "bloom", "db": -2.0, "gap": 1.5, "local": true},
}

## Looping sounds that sit under everything: the file, its folder under audio/, its bus and its level in decibels. The Sound node
## fades each with how near its nearest source is (see `loop_db`).
const LOOPS := {
	"valley_day": {"file": "valley_day", "dir": "ambience", "bus": "Ambience", "db": -2.0},
	"valley_night": {"file": "valley_night", "dir": "ambience", "bus": "Ambience", "db": -2.0},
	"bloom_near": {"file": "bloom_near", "dir": "ambience", "bus": "Ambience", "db": -4.0},
	"scorch": {"file": "scorch", "dir": "sfx", "bus": "Sfx", "db": -9.0},
	"lamp_hum": {"file": "lamp_hum", "dir": "sfx", "bus": "Sfx", "db": -11.0},
	"cart": {"file": "cart", "dir": "sfx", "bus": "Sfx", "db": -10.0},
}

var rng := RandomNumberGenerator.new()
var _last: Dictionary = {}  # cue id -> the time it last played
var _next: Dictionary = {}  # cue id -> the file it plays next (they take turns, so one never repeats at once)
var _voices: Array = []  # {id, group, end}: sounds still sounding
var _recent: Array = []  # the times of recent everyday plays, for the crowd


## The share of full strength (0 to 1) of a sound `tiles` away from the middle of the view. `view_k` is the zoom: above 1 the view
## shows more ground (zoomed out), so a sound carries further in tiles; below 1 it carries less. A negative distance means a sound
## with no place, heard in full.
static func near_gain(tiles: float, view_k := 1.0) -> float:
	if tiles < 0.0:
		return 1.0
	var d := tiles / maxf(view_k, 0.1)
	if d <= FULL_TILES:
		return 1.0
	if d >= FAR_TILES:
		return 0.0
	var t := (FAR_TILES - d) / (FAR_TILES - FULL_TILES)
	return t * t


## The level of a loop in decibels: its own level, faded by how near its nearest source is, and a little louder for a crowd of
## sources (up to 3 dB for eight or more). -80 when nothing is within hearing.
static func loop_db(base_db: float, nearest_tiles: float, count: int, view_k := 1.0) -> float:
	if count <= 0:
		return -80.0
	var gain := near_gain(nearest_tiles, view_k)
	if gain < MIN_GAIN:
		return -80.0
	return base_db + linear_to_db(gain) + 3.0 * minf(log(float(count)) / log(8.0), 1.0)


## Ask to play `id` now (`now`, in seconds of the clock the caller keeps), from `tiles` away from the middle of the view (-1 for no
## place), for a sound `length` seconds long. Returns {} when it should not play, else {file, bus, db, pitch}. A returned sound
## counts as playing until `now + length`.
func request(id: String, tiles: float, now: float, length := 1.0, view_k := 1.0) -> Dictionary:
	if not CUES.has(id):
		return {}
	var def: Dictionary = CUES[id]
	var group: String = def["group"]
	if now - float(_last.get(id, -1000.0)) < float(def["gap"]):
		return {}
	var gain := near_gain(tiles, view_k) if def["local"] else 1.0
	if gain < MIN_GAIN:
		return {}
	_voices = _voices.filter(func(v): return v["end"] > now)
	_recent = _recent.filter(func(t): return t > now - CROWD_WINDOW)
	var everyday: bool = group in EVERYDAY
	if everyday and _recent.size() >= BUSY_PLAYS:
		return {}
	if _voices.size() >= MAX_VOICES and group != "event":
		return {}
	if _voices.filter(func(v): return v["group"] == group).size() >= int(GROUP_VOICES[group]):
		return {}
	var duck := 0.0
	if everyday:
		duck = minf(MAX_DUCK, maxf(0.0, float(_recent.size() - CALM_PLAYS)) * DUCK_PER_PLAY)
		_recent.append(now)
	_last[id] = now
	_voices.append({"id": id, "group": group, "end": now + length})
	var files: Array = def["files"]
	var at: int = int(_next.get(id, rng.randi() % files.size())) % files.size()
	_next[id] = at + 1
	return {
		"file": files[at],
		"bus": "Sfx",
		"db": float(def["db"]) + linear_to_db(gain) - duck,
		"pitch": rng.randf_range(0.97, 1.03),
	}


## How many sounds are sounding at `now` (tests, and the Sound node's pool).
func sounding(now: float) -> int:
	return _voices.filter(func(v): return v["end"] > now).size()


## Forget everything played (a new run).
func reset() -> void:
	_last = {}
	_next = {}
	_voices = []
	_recent = []
