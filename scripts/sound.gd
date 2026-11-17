extends Node
## The game's sound, owned by main. Every frame main calls `update` with the run, where the view is looking and how far it is
## zoomed; this plays what the blocks noted on the cue bus (scripts/sound_cues.gd), as the rules in scripts/sound_mix.gd allow,
## and keeps the ambient loops (the valley, the Bloom, Scorchers, Arc Lamps, carts) fading with how near their sources are.
## Every button that appears in the tree gets a click. Volume and mute are the player's (scripts/sound_settings.gd). Music is not
## here: it is on hold.

const Cues = preload("res://scripts/sound_cues.gd")
const Mix = preload("res://scripts/sound_mix.gd")
const Settings = preload("res://scripts/sound_settings.gd")
const Kith = preload("res://scripts/kith.gd")

const POOL := Mix.MAX_VOICES + 2  # players for one-shots: the mix's voices, and two spare for events
const LOOP_EVERY := 0.2  # seconds between looks at the loops
const BLOOM_EVERY := 0.5  # seconds between searches for the Bloom nearest the view
const NIGHT_FADE := 6.0  # seconds the valley takes to turn from day to night
const SILENT := -80.0

var mix := Mix.new()
var clock := 0.0  # real seconds this node has run (the mix's clock; the game's pause and speed do not matter here)
var listener := Vector2.ZERO  # the tile (as a point) at the middle of the view
var view_k := 1.0  # above 1 the view is zoomed out
var _pool: Array = []
var _streams: Dictionary = {}  # "dir/file" -> AudioStream, or null for a file that did not load
var _loops: Dictionary = {}  # loop id -> its AudioStreamPlayer
var _loop_clock := 0.0
var _bloom_clock := 0.0
var _bloom_nearest := -1.0
var _night := 0.0  # 0 the valley by day, 1 by night


func _ready() -> void:
	Cues.clear()
	Cues.listening = true
	Settings.apply()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = Settings.SFX_BUS
		add_child(p)
		_pool.append(p)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	Cues.listening = false
	Cues.clear()


## One frame of sound. `s` is the run (a Sim), `view_tile` the map tile the view is centred on, `zoom_k` the view's zoom relative to
## the default (above 1 shows more ground), `delta` real seconds.
func update(delta: float, s, view_tile: Vector2, zoom_k: float) -> void:
	clock += delta
	listener = view_tile
	view_k = zoom_k
	for cue in Cues.take():
		play(cue["id"], cue["at"])
	_loop_clock += delta
	if _loop_clock >= LOOP_EVERY:
		_loops_tick(s, _loop_clock)
		_loop_clock = 0.0


## Play the cue `id` from tile `at` (-1, -1 for no place) if the mix allows. Returns true when it started.
func play(id: String, at := Vector2i(-1, -1)) -> bool:
	if not Mix.CUES.has(id):
		return false
	var tiles := -1.0 if at.x < 0 else listener.distance_to(Vector2(at) + Vector2(0.5, 0.5))
	var first: AudioStream = _stream("sfx", Mix.CUES[id]["files"][0])
	var length := first.get_length() if first != null else 1.0
	var go := mix.request(id, tiles, clock, length, view_k)
	if go.is_empty():
		return false
	var stream: AudioStream = _stream("sfx", go["file"])
	if stream == null:
		return false
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.bus = go["bus"]
			p.volume_db = go["db"]
			p.pitch_scale = go["pitch"]
			p.play()
			return true
	return false


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.pressed.is_connected(_click):
		n.pressed.connect(_click)


func _click() -> void:
	play("ui_click")


## The stream for `dir`/`file` (a name in audio/, no extension), loaded once. Null when it is not there (an unimported file).
func _stream(dir: String, file: String) -> AudioStream:
	var key := dir + "/" + file
	if not _streams.has(key):
		var path := "res://audio/%s.ogg" % key
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
	return _streams[key]


## Fade the loops: the valley (day, then night once the star has fallen), the Bloom near the view, and the sources that hum.
func _loops_tick(s, dt: float) -> void:
	var target := 1.0 if s.starfall.stage != "" else 0.0
	_night = move_toward(_night, target, dt / NIGHT_FADE)
	_set_loop("valley_day", SILENT if _night >= 0.999 else Mix.LOOPS["valley_day"]["db"] + linear_to_db(1.0 - _night))
	_set_loop("valley_night", SILENT if _night <= 0.001 else Mix.LOOPS["valley_night"]["db"] + linear_to_db(_night))
	_bloom_clock += dt
	if _bloom_clock >= BLOOM_EVERY:
		_bloom_clock = 0.0
		_bloom_nearest = _nearest(s.tide.grown.keys()) if s.tide.begun else -1.0
	_set_loop(
		"bloom_near",
		Mix.loop_db(Mix.LOOPS["bloom_near"]["db"], _bloom_nearest, 1 if _bloom_nearest >= 0.0 else 0, view_k)
	)
	_set_near("scorch", s.tide.fire_tiles())
	_set_near("lamp_hum", s.tide.lamp_tiles())
	var carts: Array = []
	for k in s.people.kith:
		if k.get("cart", false):
			carts.append(Kith.tile_of(k))
	_set_near("cart", carts)


## Set loop `id` from the tiles of its sources: the nearest one sets how loud, how many sources adds a little.
func _set_near(id: String, tiles: Array) -> void:
	_set_loop(id, Mix.loop_db(Mix.LOOPS[id]["db"], _nearest(tiles), tiles.size(), view_k))


## The distance in tiles from the view's middle to the nearest of `tiles` (-1 when there are none).
func _nearest(tiles: Array) -> float:
	var best := -1.0
	for t in tiles:
		var d := listener.distance_to(Vector2(t) + Vector2(0.5, 0.5))
		if best < 0.0 or d < best:
			best = d
	return best


## Put loop `id` at `db` (SILENT or below stops it; a loop that has never been heard is not even loaded).
func _set_loop(id: String, db: float) -> void:
	var p: AudioStreamPlayer = _loops.get(id)
	if p == null:
		if db <= SILENT + 1.0:
			return
		var def: Dictionary = Mix.LOOPS[id]
		var stream := _stream(def["dir"], def["file"])
		if stream == null:
			return
		p = AudioStreamPlayer.new()
		p.stream = stream
		p.bus = def["bus"]
		add_child(p)
		_loops[id] = p
	if db <= SILENT + 1.0:
		if p.playing:
			p.stop()
		return
	p.volume_db = db
	if not p.playing:
		p.play()
