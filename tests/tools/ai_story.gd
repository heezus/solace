extends RefCounted
## The AI player's story hands (design-system/25-playtesting.md, "The table reaches the reset"): what a person does beside the town once the
## story begins. It reads and guesses the marks on the Glyph Wall, watches or skips a cutscene, opens the ending card and an ending's
## details, sets out on an ending (the run folds into a profile and a new run begins with the carry) and reads the Chronicle. Every move
## goes through the game's own commands (Starfall.cycle_guess, Profile.set_out, Launch.begin_new); nothing here reaches past them.
## `lines` is the page's story part, `move` runs one story move and says why it was refused ("" when it was taken).

const Chronicle = preload("res://scripts/chronicle.gd")
const Data = preload("res://scripts/data.gd")
const Endings = preload("res://scripts/endings.gd")
const Launch = preload("res://scripts/launch.gd")
const OldShip = preload("res://scripts/old_ship.gd")
const Profile = preload("res://scripts/profile.gd")
const SimScript = preload("res://scripts/sim.gd")

const MOVES := ["guess", "scene", "endings", "ending_details", "set_out", "chronicle"]
const MARK_ROWS := 5  # a mark is drawn on a grid this many rows and ...
const MARK_COLS := 9  # ... this many columns, as the Wall draws its strokes

static var profile_path := "user://ai_profile.json"  # where the table's own profile lives (the table is one player's whole game)
static var next_run = null  # the Sim of the telling the last set_out began; the table takes it
static var _sim_id := 0  # the Sim the scene list below belongs to
static var _scenes := {}  # sequence id -> "waiting", "watched" or "skipped"
static var _told: Array = []  # lines the next page opens with (a scene just watched, the Chronicle just opened)
static var _card_open := false  # the ending card has been opened
static var _details: Array = []  # endings whose details were opened


## Start the table over: a first game, no profile, nothing offered.
static func reset(path := "user://ai_profile.json") -> void:
	profile_path = path
	Profile.forget(path)
	next_run = null
	_sim_id = 0
	_scenes = {}
	_told = []
	_card_open = false
	_details = []


## The Sim the last set_out began, once; null when none (the table swaps its game for it).
static func take_next():
	var out = next_run
	next_run = null
	return out


## The page's story part: lines the last move told, the Glyph Wall, the scenes waiting, and the ending card.
static func lines(s) -> Array:
	_follow(s)
	var out: Array = _told.duplicate()
	_told = []
	out.append_array(_wall(s))
	out.append_array(_waiting(s))
	out.append_array(_card(s))
	return out


## Run one story move. Returns why it was refused, "" when it was taken.
static func move(s, m: Dictionary) -> String:
	_follow(s)
	match str(m.get("do", "")):
		"guess":
			return _guess(s, str(m.get("mark", "")), str(m.get("word", "")))
		"scene":
			return _scene(s, str(m.get("id", "")), str(m.get("action", "watch")))
		"endings":
			if not set_out_open(s):
				return "Skyward does not stand yet, so no ending can be chosen"
			_card_open = true
			return ""
		"ending_details":
			return _open_details(s, str(m.get("ending", "")))
		"set_out":
			return _set_out(s, str(m.get("ending", "")), str(m.get("scenes", "watch")) == "skip")
		"chronicle":
			var profile := Profile.new()
			profile.load_file(profile_path)
			_told.append_array(_book(profile, profile.tellings.size() - 1, false))
			return ""
	return "not a story move"


## True once an ending can be chosen: Skyward stands (a later run: the Skyreach).
static func set_out_open(s) -> bool:
	return s.story.events.has(Data.SKYWARD_EVENT if s.carry.is_first() else Data.SKYREACH["done"])


## Forget the scenes of another game when the table is now playing a different Sim; a new run opens with its opening, and the telling
## that follows an ending with the next land too.
static func _follow(s) -> void:
	if s.get_instance_id() == _sim_id:
		return
	_sim_id = s.get_instance_id()
	_scenes = {}
	_card_open = false
	_details = []
	var young: bool = s.seasons.time < 60.0  # a game just begun plays its opening; a stage start has played it
	for id in Data.CUTSCENES:
		var triggers: Array = Data.CUTSCENES[id]["triggers"]
		if triggers.has("start"):
			_scenes[id] = "waiting" if young else "skipped"
		elif triggers.any(func(t): return s.story.events.has(t)):
			_scenes[id] = "skipped"  # played before the table began: not offered again
	if young and s.carry.exodus > 0 and Data.CUTSCENES.has("next_telling"):
		_scenes["next_telling"] = "waiting"


# --- The Glyph Wall -----------------------------------------------------------------------------------------------


## The marks on the Wall, set by set, each as a small drawing with where it was found and the word set on it.
static func _wall(s) -> Array:
	var f = s.starfall
	if f.copied.is_empty():
		return []
	var how := "GLYPH WALL: each mark is a drawing. Say what it means with a guess move; the Kith talk the guesses over every %d s"
	how += " and read a set only when all of its marks hold the right word. A wrong guess costs only time. Words: %s"
	var out: Array = [how % [int(Data.CHECK_SECONDS), ", ".join(Data.GLYPH_WORDS)]]
	for n in _sets(s):
		var gset: Dictionary = OldShip.set_def(n)
		if f.locked.has(gset["id"]):
			out.append("  %s" % Data.WALL_SET_LOCKED % gset["name"])
		else:
			var have: Vector2i = f.progress(gset["id"])
			if have.x == 0:
				continue
			out.append("  %s" % _set_line(s, gset, have))
		var marks: Array = f.glyph_order(n)
		for i in marks.size():
			var g: String = marks[i]
			if not f.copied.has(g):
				continue
			var means: String = f.guesses.get(g, Data.NO_GUESS)
			var read: bool = f.locked.has(gset["id"]) or f.carry.knows_mark(g)
			out.append(
				(
					"    mark %s: means %s%s. Found %s"
					% [_handle(s, n, i), means, " (read)" if read else "", ", ".join(f.found_lines(g))]
				)
			)
			if not read:
				out.append_array(_drawing(g))
	return out


static func _set_line(s, gset: Dictionary, have: Vector2i) -> String:
	if gset.has("run"):
		return Data.ENDINGS["old"]["set_line"] % [have.x, have.y]
	return Data.WALL_SET_LINE % [s.starfall.set_number(gset["id"]), Data.GLYPH_SETS.size(), have.x, have.y]


## The sets the Wall shows, in the order it meets them: the six, then the old ones this run can read.
static func _sets(s) -> Array:
	var out: Array = s.starfall.set_order()
	for n in OldShip.sets(s.starfall):
		out.append(n)
	return out


## The handle a mark is called by on the page: its set's place on the Wall and its own place in the set ("2.1"). It names no word.
static func _handle(s, n: int, index: int) -> String:
	var order: Array = _sets(s)
	return "%d.%d" % [order.find(n) + 1, index + 1]


## The mark a handle names, "" for none.
static func _glyph_of(s, handle: String) -> String:
	var parts := handle.split(".")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return ""
	var order: Array = _sets(s)
	var at: int = int(parts[0]) - 1
	if at < 0 or at >= order.size():
		return ""
	var marks: Array = s.starfall.glyph_order(order[at])
	var i: int = int(parts[1]) - 1
	return marks[i] if i >= 0 and i < marks.size() else ""


## A mark's strokes drawn with # on a small grid, as the Wall draws them (a person sees the drawing).
static func _drawing(glyph: String) -> Array:
	var grid: Array = []
	for r in MARK_ROWS:
		grid.append(".".repeat(MARK_COLS).split(""))
	for stroke in Data.GLYPHS[glyph]["strokes"]:
		for k in range(stroke.size() - 1):
			var a := Vector2(stroke[k][0], stroke[k][1])
			var b := Vector2(stroke[k + 1][0], stroke[k + 1][1])
			for step in 13:
				var p := a.lerp(b, step / 12.0)
				var col := clampi(roundi(p.x * (MARK_COLS - 1)), 0, MARK_COLS - 1)
				var row := clampi(roundi(p.y * (MARK_ROWS - 1)), 0, MARK_ROWS - 1)
				grid[row][col] = "#"
	var out: Array = []
	for row in grid:
		out.append("        " + "".join(row))
	return out


## Set the guess on a mark to `word` by moving it through the list the Wall's button moves it through.
static func _guess(s, handle: String, word: String) -> String:
	var f = s.starfall
	var glyph := _glyph_of(s, handle)
	if glyph == "":
		return "no mark %s on the Wall" % handle
	if not f.copied.has(glyph):
		return "that mark is not on the Wall yet"
	if f.locked.has(f.set_of(glyph)) or f.carry.knows_mark(glyph):
		return "that mark is already read"
	var list: Array = OldShip.words_for(glyph)
	var want := ""
	for w in list:
		if str(w).to_lower() == word.to_lower():
			want = w
	if want == "":
		return "the Wall has no word '%s' to set" % word
	for i in list.size():
		if f.guesses.get(glyph, "") == want:
			return ""
		if f.cycle_guess(glyph) == "":
			break
	if f.guesses.get(glyph, "") == want:
		return ""
	return "'%s' is the meaning of a mark already read, so no other mark can take it" % word


# --- Scenes -------------------------------------------------------------------------------------------------------


## The scenes a story event brought up that nobody has watched or skipped yet.
static func _waiting(s) -> Array:
	for id in Data.CUTSCENES:
		if not _scenes.has(id) and Data.CUTSCENES[id]["triggers"].any(func(t): return s.story.events.has(t)):
			_scenes[id] = "waiting"
	var out: Array = []
	for id in _scenes:
		if _scenes[id] == "waiting":
			(
				out
				. append(
					(
						'SCENE WAITING: %s (%d stills). Watch it ({"do":"scene","id":"%s","action":"watch"}) or skip it ("action":"skip").'
						% [id, Data.CUTSCENES[id]["stills"].size(), id]
					)
				)
			)
	return out


## Watch or skip the scene `id`: watching tells its lines on the next page; either is noted for the playtest log.
static func _scene(s, id: String, action: String) -> String:
	if _scenes.get(id, "") != "waiting":
		return "no scene '%s' is waiting" % id
	if action != "watch" and action != "skip":
		return "a scene is watched or skipped"
	_scenes[id] = "watched" if action == "watch" else "skipped"
	_note(s, id, action == "skip")
	if action == "watch":
		_told.append("SCENE %s:" % id)
		for still in Data.CUTSCENES[id]["stills"]:
			_told.append("  " + still["line"])
	return ""


static func _note(s, id: String, skipped: bool) -> void:
	if s.seasons.watcher != null:
		s.seasons.watcher.event(s, "cutscene", {"id": id, "skipped": skipped, "secs": 0.0})


# --- The ending card, set out and the Chronicle -------------------------------------------------------------------


## The ending card when it is open (one row for each ending, what it gives and why one is shut).
static func _card(s) -> Array:
	if not set_out_open(s):
		return []
	if not _card_open:
		return ['SKYWARD STANDS: the telling can end. Say {"do":"endings"} to see the ending card, or keep building.']
	var title: String = (
		Data.ENDINGS["title_first"] if s.carry.is_first() else Data.ENDINGS["title_later"] % (s.carry.exodus + 1)
	)
	var out: Array = ["ENDING CARD: %s. %s" % [title, Data.ENDINGS["text"]]]
	var rows: Array = Data.ENDINGS["order"].duplicate()
	if Endings.way_open(s):
		rows.append_array(Data.ENDINGS["true_order"])
	for id in rows:
		var e: Dictionary = Data.ENDINGS[id]
		var why: String = _why_shut(s, id)
		out.append(
			(
				"  %s: %s %s%s"
				% [
					id,
					e["name"],
					e["line"],
					(" Shut: %s." % why) if why != "" else " " + (Data.ENDINGS["gives"] % e["gives"])
				]
			)
		)
		if _details.has(id):
			out.append("    Details: %s" % e["end"])
	out.append(
		(
			'  Open an ending\'s details with {"do":"ending_details","ending":"exodus"}; end the telling with '
			+ '{"do":"set_out","ending":"exodus"} (add "scenes":"skip" to skip what follows). Or keep building.'
		)
	)
	return out


static func _why_shut(s, id: String) -> String:
	if Endings.is_true(id):
		return Endings.true_why(id, s)
	return Endings.why_locked(id, s.starfall.lean)


static func _open_details(_s, id: String) -> String:
	if not _card_open:
		return "the ending card is not open (use the endings move)"
	if not Data.ENDINGS.has(id) or not Data.ENDINGS[id] is Dictionary or not Data.ENDINGS[id].has("end"):
		return "no such ending"
	if not _details.has(id):
		_details.append(id)
	return ""


## End the telling on `ending`: the run folds into the profile, and a new run begins from its carry (the new Sim is `next_run`).
static func _set_out(s, ending: String, skip_scenes: bool) -> String:
	if not set_out_open(s):
		return "Skyward does not stand yet, so no ending can be chosen"
	if not Data.ENDINGS.has(ending) or not Data.ENDINGS[ending] is Dictionary or not Data.ENDINGS[ending].has("lean"):
		return "no such ending"
	var why := _why_shut(s, ending)
	if why != "":
		return "that ending is shut: %s" % why
	var told: Array = []
	s.story.record(Data.ENDINGS[ending]["id"])
	for id in Data.CUTSCENES:  # the scenes the ending's story moment brings, told before the next telling begins
		if Data.CUTSCENES[id]["triggers"].has(Data.ENDINGS[ending]["id"]):
			_note(s, id, skip_scenes)
			if not skip_scenes:
				told.append("SCENE %s:" % id)
				for still in Data.CUTSCENES[id]["stills"]:
					told.append("  " + still["line"])
	var profile = Profile.set_out(s, profile_path, ending)
	if not profile.saved:
		return Data.ENDINGS["unsaved"]
	var seed_used: int = (
		int(profile.last.get("seed", s.world.map_seed)) if ending == "cataclysm" else s.world.map_seed + 1
	)
	var fresh = SimScript.new()
	Launch.begin_new(fresh, seed_used, profile_path)
	next_run = fresh
	_told = told
	_told.append_array(_book(profile, profile.tellings.size() - 1, true))
	_told.append(
		"A NEW TELLING BEGINS (run %d, after the %s)." % [fresh.carry.exodus + 1, Data.ENDINGS[ending]["name"]]
	)
	return ""


## The Chronicle open on telling `at` (the one that just ended, or the last), as lines: its numbers, its stars, and the count of tellings.
static func _book(profile, at: int, after_ending: bool) -> Array:
	if at < 0 or at >= profile.tellings.size():
		return ["THE CHRONICLE: nothing is written in it yet."]
	var telling: Dictionary = profile.tellings[at]
	var out: Array = [
		(
			"THE CHRONICLE%s: telling %d of %d. %s"
			% [
				" opens on the telling that just ended" if after_ending else "",
				at + 1,
				profile.tellings.size(),
				Chronicle.numbers_line(telling)
			]
		)
	]
	var eras := Chronicle.eras_line(telling)
	if eras != "":
		out.append("  " + eras)
	for star in Chronicle.stars_of(telling):
		out.append(
			(
				"  * %s: %s %s (%s) %s"
				% [star["name"], star["question"], star["label"], Chronicle.voice_name(star["voice"]), star["text"]]
			)
		)
	return out
