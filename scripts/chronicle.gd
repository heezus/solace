extends RefCounted
## The Chronicle's sky (Step 7G, design-system/18-roadmap.md "The Chronicle as built"): what the book shows, worked out from the profile
## (scripts/profile.gd) and nothing else. Each ended telling is one constellation of stars, one per choice point of the Starfall and
## one for the lean and the ending; only what happened is drawn. A star's entry is written by whoever was there, and each road not taken
## is wondered about by one voice (`whispers`). From the third telling the Bloom adds a broken fragment. Embers are hidden moments a
## run shows (`embers_of`): they light a small star the first time they are seen. `map_of` keeps a small picture of a telling's land.
## The words are scripts/chronicle_words.gd. Static, and reads plain dictionaries (a profile's `tellings`), never the Sim, except
## `embers_of` and `map_of`, which look at the run that is ending.

const Data = preload("res://scripts/data.gd")
const Words = preload("res://scripts/chronicle_words.gd")

const ERA_NAMES := [Data.ERA_STONE, Data.ERA_BRONZE, Data.ERA_STARFALL, Data.ERA_IRONFALL, Data.ERA_LIVEWIRE]
const MAP_STRIDE := 1  # tiles per cell of a telling's small map: one a tile, drawn small in the book
# What a cell shows when several tiles fall in it, first wins: building, Bloom, road, ruins, river, trees, rock, grass.
const MAP_ORDER := "#b=fr~t^."


## The option of star `kind` that `telling` (a record of Endings.telling) took, "" when the star was never asked.
static func option_of(kind: String, telling: Dictionary) -> String:
	if kind == "lean":
		return String(telling.get("lean", ""))
	if kind == "ending":
		return String(telling.get("ending", ""))
	var choices: Array = telling.get("choices", [])
	var options: Dictionary = Words.STARS[kind]["options"]
	for id in options:
		if options[id]["event"] != "" and options[id]["event"] in choices:
			return id
	return "unraised" if kind == "cairn" else ""


## The stars of `telling`, in the order they were asked: {kind, name, question, option, label, voice, text, whispers, bloom}.
## `whispers` is one {voice, text} for each road not taken; `bloom` is the Bloom's fragment from the third telling on, else "".
static func stars_of(telling: Dictionary) -> Array:
	var out: Array = []
	for kind in Words.STAR_ORDER:
		var option := option_of(kind, telling)
		var star: Dictionary = Words.STARS[kind]
		if option == "" or not star["options"].has(option):
			continue
		var whispers: Array = []
		for other in star["options"]:
			if other != option:
				whispers.append(star["options"][other]["whisper"])
		var entry: Dictionary = star["options"][option]["entry"]
		(
			out
			. append(
				{
					"kind": kind,
					"name": star["name"],
					"question": star["question"],
					"option": option,
					"label": star["options"][option]["label"],
					"voice": entry["voice"],
					"text": entry["text"],
					"whispers": whispers,
					"bloom": star["bloom"] if int(telling.get("run", 1)) >= Words.BLOOM_FROM else "",
				}
			)
		)
	return out


## The sky: one constellation per ended telling, in order, {run, ending, lean, trust, stars, embers, numbers, map}. Empty for a
## profile with no ended telling.
static func sky(tellings: Array) -> Array:
	var out: Array = []
	for t in tellings:
		(
			out
			. append(
				{
					"run": int(t.get("run", out.size() + 1)),
					"ending": String(t.get("ending", "")),
					"lean": String(t.get("lean", "")),
					"trust": float(t.get("trust", 0.0)),
					"stars": stars_of(t),
					"embers": Array(t.get("embers", [])),
					"numbers": numbers_line(t),
					"map": t.get("map", {}),
				}
			)
		)
	return out


## The numbers of a telling in one line, "" for a record from before they were kept.
static func numbers_line(telling: Dictionary) -> String:
	if not telling.has("minutes"):
		return ""
	return (
		Words.NUMBERS
		% [
			roundi(float(telling["minutes"])),
			int(telling.get("kin", 0)),
			int(telling.get("buildings", 0)),
			int(telling.get("lost", 0))
		]
	)


## The minutes each era took in one line ("Stone Age 10 · Bronze Dawn 10 ..."), "" for a record from before they were kept.
static func eras_line(telling: Dictionary) -> String:
	var eras: Array = telling.get("eras", [])
	var parts: Array = []
	for i in mini(eras.size(), ERA_NAMES.size()):
		parts.append("%s %d" % [ERA_NAMES[i], roundi(float(eras[i]))])
	return " · ".join(parts)


## The words of `voice` ("elder", "sela", ...) as a name.
static func voice_name(voice: String) -> String:
	return Words.VOICES.get(voice, voice)


## The Embers the run in `s` (a Sim) shows, in Words.EMBER_ORDER. Not the ones found before: the caller keeps what is new.
static func embers_of(s) -> Array:
	var found: Array = []
	var story = s.story
	var has_all := func(ids: Array) -> bool: return ids.all(func(id): return story.has_event(id))
	if has_all.call(["hunger_shared", "shards_given", "dark_kept"]):
		found.append("open_hands")
	if has_all.call(["hunger_held", "shards_refused", "dark_refused"]):
		found.append("closed_doors")
	if story.cairn_before_landing:
		found.append("cairn_first")
	if story.has_event("lean_allies") and not story.has_event("cairn_raised"):
		found.append("lone_fire")
	if story.has_event("old_ship_found"):
		found.append("ship_found")
	if s.carry.dug.size() >= Data.ENDINGS["relics"].size():
		found.append("three_gifts")
	var reads := ["name_read", "light_read", "body_read", "growth_read", "craft_read", "warning_read"]
	reads.append_array(["ship_read", "broke_read", "way_read"])
	if has_all.call(reads):
		found.append("whole_word")
	return found.filter(func(id): return Words.EMBERS.has(id))


## The small map of the land the run in `s` (a Sim) ends on: {"cell", "w", "h", "rows"}, a row a string of one character a cell
## (MAP_ORDER names them: "#" a building, "b" Bloom, "=" a road, "f" a field, "r" ruins, "~" a river, "t" trees, "^" rock and ore,
## "." grass).
static func map_of(s) -> Dictionary:
	var w: int = s.world.width
	var h: int = s.world.height
	var rows: Array = []
	for cy in range(0, h, MAP_STRIDE):
		var row := ""
		for cx in range(0, w, MAP_STRIDE):
			row += _cell(s, cx, cy, w, h)
		rows.append(row)
	return {"cell": MAP_STRIDE, "w": w, "h": h, "rows": rows}


static func _cell(s, cx: int, cy: int, w: int, h: int) -> String:
	var best := MAP_ORDER.length() - 1
	for y in range(cy, mini(cy + MAP_STRIDE, h)):
		for x in range(cx, mini(cx + MAP_STRIDE, w)):
			var p := Vector2i(x, y)
			best = mini(best, MAP_ORDER.find(_mark(s, p)))
	return MAP_ORDER[best]


static func _mark(s, p: Vector2i) -> String:
	if s.town.building_at.has(p):
		return "#"
	var tile: String = s.world.tile_at(p)
	if tile.begins_with("bloom_"):
		return "b"
	if s.world.roads.has(p):
		return "="
	if s.world.fields.has(p) or s.world.flax_fields.has(p):
		return "f"
	match tile:
		"ruins":
			return "r"
		"river":
			return "~"
		"tree":
			return "t"
		"rock", "copper_hills", "iron_hills", "coal_seam", "spent_seam", "tin_stream", "gravel", "clay":
			return "^"
	return "."


## The sequences of Data.CUTSCENES a player can watch again: the ones whose story has happened in any telling, in play order. The
## opening and the next land are open once a telling has ended. {id, name}.
static func scenes(chronicle: Array, runs: int) -> Array:
	var out: Array = []
	for id in Data.CUTSCENES:
		var def: Dictionary = Data.CUTSCENES[id]
		var seen: bool = (
			(runs > 0 and (id == "opening" or id == "next_telling"))
			or def["triggers"].any(func(t): return t in chronicle)
		)
		if seen and Words.SCENES.has(id):
			out.append({"id": id, "name": Words.SCENES[id]})
	return out


## The four layers of lore, each {title, text, open}: a layer's text shows once its story id is in `chronicle`.
static func layers(chronicle: Array) -> Array:
	var out: Array = []
	for layer in Words.LAYERS:
		out.append({"title": layer["title"], "text": layer["text"], "open": layer["event"] in chronicle})
	return out


## The nine sets of marks, {n, name, read, glyphs: [{id, word, strokes, read}]}: a mark shows once its id is in `marks`.
static func dictionary(marks: Array) -> Array:
	var out: Array = []
	var sets: Dictionary = Data.GLYPH_SETS.duplicate()
	sets.merge(Data.ENDINGS["old"]["sets"])
	var numbers := sets.keys()
	numbers.sort()
	for n in numbers:
		var glyphs: Array = []
		var all := true
		for id in sets[n]["glyphs"]:
			var read: bool = id in marks
			all = all and read
			glyphs.append(
				{"id": id, "word": Data.GLYPHS[id]["word"], "strokes": Data.GLYPHS[id]["strokes"], "read": read}
			)
		out.append({"n": n, "name": sets[n]["name"], "read": all, "glyphs": glyphs})
	return out


## How many tellings ended in `ending`.
static func times_reached(tellings: Array, ending: String) -> int:
	return tellings.filter(func(t): return t.get("ending", "") == ending).size()
