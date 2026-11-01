extends RefCounted
## The profile: what outlives a run (design-system/12-knowledge-is-progress.md, 13-three-perspectives.md).
## Four things, and nothing else yet:
##   `chronicle`: the story event ids (Data.STORY_EVENTS) in the order they first happened, across runs. It is the
##     start of the Chronicle, the record of story moments a later run can read.
##   `knowledge`: the item ids the people have learned to gather. A future time loop rebuilds the map and
##     carries only this over, since knowledge is of kinds of things, never of places.
##   `hints`: the ids of the first-time hints already shown (scripts/hints.gd), so none comes back in a later run. A profile
##     written before hints existed has none and still loads.
##   the carry (version 2): `techs` (tech ids researched), `marks` (glyph ids read), `echoes` (Lumen set ids read) and `exoduses`
##     (how many times the Kith chose the Exodus). They are banked only by bank(), when the player ends a run with an ending
##     (scripts/endings.gd), so what a run that never ended learned is not carried. A new run begins with them as its carry
##     (scripts/carry.gd). A version 1 profile loads with them empty.
##   the tellings (version 3): `runs` (how many runs have ended), `tellings` (one record per ended run: its number, map seed,
##     the small Starfall choices, the lean, the trust and the ending) and `last` (the latest ending with what the next run
##     is made from: its seed, its end trust and, after a Cataclysm, the ruins and the dormant Bloom patches). A version 1 or 2
##     profile loads with them empty (its `runs` is its `exoduses`).
##   the Chronicle (Step 7G): `embers`, the hidden moments any telling has shown (scripts/chronicle.gd). Each telling's record also
##     keeps its numbers and a small map of its land, and the Embers it lit first. A profile without them loads with none.
##   the name (Step 7): `kin_known`, true once the first ship's marks (glyph set 7) are read in any run, from then on the people are
##     "Kin" on screen (scripts/kin_name.gd), and `kin_told`, true once the card that says so has been shown. A profile written before
##     them has `kin_known` when it holds the story moment "ship_read".
##   the blueprints (Step 7D): `blueprints`, the saved parts of towns (scripts/blueprints.gd). Only an Exodus banks the blueprints of the
##     run that ends; any other ending keeps the ones banked before. A profile without them loads with none.
## absorb(state) merges a run (finished or in progress) into the profile: new ids are added at the end, ids
## already held keep their place, and absorbing the same run twice changes nothing.
## The profile is its own file (PATH), apart from the run save (scripts/run_save.gd): a run save holds no
## profile data and the profile holds no run data (no map, stockpile, buildings, people or research).
## A missing or corrupt file gives an empty profile and prints nothing. No faction words are spelled here.
## Only the carry changes how a game starts: a run writes the rest to the profile at an ending (note_run), and the carry
## when the player sets out (set_out).

const Carry = preload("res://scripts/carry.gd")
const Endings = preload("res://scripts/endings.gd")

const VERSION := 3
const OLDEST := 1  # the oldest version still read
const PATH := "user://profile.json"
const SECTIONS := ["chronicle", "knowledge"]
const KIN_EVENT := "ship_read"  # the story moment of reading set 7 (Data.GOALS), the one that makes the people Kin

var chronicle: Array = []  # story ids, in the order they first happened
var knowledge: Array = []  # item ids, in the order they were first learned
var hints: Array = []  # first-time hint ids, in the order they were shown
var techs: Array = []  # tech ids researched in a run that set out
var marks: Array = []  # glyph ids read in a run that set out
var echoes: Array = []  # Lumen set ids read in a run that set out
var exoduses := 0  # how many times the Kith have chosen the Exodus
var runs := 0  # how many runs have ended in an ending (the Exodus, the Cataclysm or the Time loop)
var tellings: Array = []  # one record per ended run (Endings.telling), in order
var last: Dictionary = {}  # the latest ending's handoff to the next run (Endings.handoff), {} before any
var blueprints: Array = []  # the blueprints banked by an Exodus (scripts/blueprints.gd)
var embers: Array = []  # the Embers found in any telling (Chronicle.embers_of), in the order they were first lit
var kin_known := false  # the people are Kin: set 7 was read in a run (Profile.note_kin)
var kin_told := false  # the card "Your people are now called Kin." has been shown
var saved := true  # set_out: the file was written


## True while the profile holds nothing.
func is_empty() -> bool:
	return (
		chronicle.is_empty()
		and knowledge.is_empty()
		and hints.is_empty()
		and techs.is_empty()
		and marks.is_empty()
		and echoes.is_empty()
		and exoduses == 0
		and runs == 0
		and tellings.is_empty()
		and last.is_empty()
		and blueprints.is_empty()
		and embers.is_empty()
		and not kin_known
		and not kin_told
	)


## Merge the run in `s` (a Sim) into the profile: its story ids and the items its people have learned.
func absorb(s) -> void:
	merge(s.story.events, s.people.learned_by.keys())


## Merge story ids and item ids given directly. Each id is kept once, new ones go on the end in the order
## given. Anything that is not a String is ignored.
func merge(story_ids: Array, item_ids: Array) -> void:
	_add_all(chronicle, story_ids)
	_add_all(knowledge, item_ids)
	kin_known = kin_known or has_story(KIN_EVENT)


## Bank what the run in `s` taught into the carry: its techs, the marks it read and the echoes of the sets it read, and count
## one more ending, `ending` ("exodus", "cataclysm" or "loop"): its telling and what the next run is made from are kept.
## Ids already held keep their place. Only set_out calls this.
func bank(s, ending := "exodus") -> void:
	var earned := Carry.earned(s)
	_add_all(techs, earned["techs"])
	_add_all(marks, earned["marks"])
	_add_all(echoes, earned["echoes"])
	runs += 1
	if ending == "exodus":
		exoduses += 1
		blueprints = s.carry.blueprints.duplicate(true)  # the run's book: the ones it began with and the ones it saved
		for bp in blueprints:
			bp["banked"] = true  # from now on they are carried knowledge
	var record := Endings.telling(s, ending)
	var shown: Array = record["embers"]
	record["embers"] = shown.filter(func(id): return not id in embers)  # the telling that first lit an Ember keeps it
	_add_all(embers, shown)
	tellings.append(record)
	last = Endings.handoff(s, ending)


## The carry a run begins with: what has been banked, which telling the run is, and what the last ending made of its world.
func carry() -> Carry:
	var c := Carry.new()
	c.techs = techs.duplicate()
	c.marks = marks.duplicate()
	c.echoes = echoes.duplicate()
	c.exodus = runs
	for t in tellings:
		c.reached.append(String(t.get("ending", "")))
	c.set_handoff(last)
	c.blueprints = blueprints.duplicate(true)
	for bp in c.blueprints:
		bp["banked"] = true
	if c.ending == "" and c.exodus > 0:
		c.ending = "exodus"  # a version 2 profile: its runs all set out
	return c


## True when the first-time hint `id` has been shown in any run.
func has_hint(id: String) -> bool:
	return id in hints


## Fold the shown hint `id` into the profile saved at `path` and write it back. False when the file could not be written.
static func note_hint(id: String, path: String = PATH) -> bool:
	var profile := new()
	profile.load_file(path)
	_add_all(profile.hints, [id])
	return profile.save(path)


## Fold "the first ship's marks were read" into the profile saved at `path` and write it back: the people are Kin from now on, in
## every run. `told` also notes that the card was shown. False when the file could not be written.
static func note_kin(told := false, path: String = PATH) -> bool:
	var profile := new()
	profile.load_file(path)
	profile.kin_known = true
	profile.kin_told = profile.kin_told or told
	return profile.save(path)


## True when the profile saved at `path` says the people are Kin (a missing file says no).
static func kin_known_at(path: String = PATH) -> bool:
	var profile := new()
	profile.load_file(path)
	return profile.kin_known


func knows(item: String) -> bool:
	return item in knowledge


## True when the story moment `id` (Data.STORY_EVENTS) has happened in any run.
func has_story(id: String) -> bool:
	return id in chronicle


## Fold the run in `s` into the profile saved at `path` (a missing or corrupt file is an empty one) and write it back.
## False when the file could not be written. The run save is not touched.
static func note_run(s, path: String = PATH) -> bool:
	var profile := new()
	profile.load_file(path)
	profile.absorb(s)
	return profile.save(path)


## The player ends the run with `ending`: fold the run in `s` into the profile saved at `path` (note_run's work), bank its carry
## and write it back. Returns the profile as banked; `saved` says whether the file was written (the carry holds for the next
## run either way).
static func set_out(s, path: String = PATH, ending := "exodus"):
	var profile := new()
	profile.load_file(path)
	profile.absorb(s)
	profile.bank(s, ending)
	profile.saved = profile.save(path)
	return profile


## Forget every past run: the file at `path` is removed, so the next game is a first game. False when it could not be removed.
static func forget(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(path) == OK


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"chronicle": chronicle.duplicate(),
		"knowledge": knowledge.duplicate(),
		"hints": hints.duplicate(),
		"techs": techs.duplicate(),
		"marks": marks.duplicate(),
		"echoes": echoes.duplicate(),
		"exoduses": exoduses,
		"runs": runs,
		"tellings": tellings.duplicate(true),
		"last": last.duplicate(true),
		"blueprints": blueprints.duplicate(true),
		"embers": embers.duplicate(),
		"kin_known": kin_known,
		"kin_told": kin_told,
	}


## Replace the profile with `d`. Anything that isn't a profile of this version gives an empty profile, and
## the stray entries in a good one (not strings, repeats) are dropped.
func from_dict(d) -> void:
	chronicle = []
	knowledge = []
	hints = []
	techs = []
	marks = []
	echoes = []
	exoduses = 0
	runs = 0
	tellings = []
	last = {}
	blueprints = []
	embers = []
	kin_known = false
	kin_told = false
	if not is_profile(d):
		return
	merge(d["chronicle"], d["knowledge"])
	for pair in [[hints, "hints"], [techs, "techs"], [marks, "marks"], [echoes, "echoes"]]:
		if typeof(d.get(pair[1])) == TYPE_ARRAY:
			_add_all(pair[0], d[pair[1]])
	if typeof(d.get("exoduses")) == TYPE_INT or typeof(d.get("exoduses")) == TYPE_FLOAT:
		exoduses = maxi(int(d["exoduses"]), 0)
	runs = exoduses  # a version 2 profile had only Exodus endings
	if typeof(d.get("runs")) == TYPE_INT or typeof(d.get("runs")) == TYPE_FLOAT:
		runs = maxi(int(d["runs"]), 0)
	if typeof(d.get("tellings")) == TYPE_ARRAY:
		tellings = d["tellings"].filter(func(x): return typeof(x) == TYPE_DICTIONARY)
	if typeof(d.get("last")) == TYPE_DICTIONARY:
		last = d["last"].duplicate(true)
	blueprints = Carry._dicts(d.get("blueprints", []))
	if typeof(d.get("embers")) == TYPE_ARRAY:
		_add_all(embers, d["embers"])
	kin_known = kin_known or d.get("kin_known") == true
	kin_told = d.get("kin_told") == true


## True when `d` looks like a profile this code can read.
static func is_profile(d) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var version = d.get("version")
	if (
		(typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT)
		or int(version) < OLDEST
		or int(version) > VERSION
	):
		return false
	for key in SECTIONS:
		if typeof(d.get(key)) != TYPE_ARRAY:
			return false
	return true


## The profile as text.
func to_json() -> String:
	return JSON.stringify(to_dict(), "", false, true)


## Replace the profile with the one in `text`. False, and an empty profile, when it isn't a profile.
func from_json(text: String) -> bool:
	var json := JSON.new()
	if json.parse(text) != OK or not is_profile(json.data):
		from_dict(null)
		return false
	from_dict(json.data)
	return true


## Write the profile to `path`. False when the file could not be written.
func save(path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_json())
	file.close()
	return true


## Replace the profile with the one at `path`. A missing, unreadable or corrupt file leaves an empty profile
## and returns false.
func load_file(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		from_dict(null)
		return false
	return from_json(FileAccess.get_file_as_string(path))


static func _add_all(into: Array, ids: Array) -> void:
	for id in ids:
		if typeof(id) == TYPE_STRING and not id in into:
			into.append(id)
