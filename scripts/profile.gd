extends RefCounted
## The profile: what outlives a run (design-system/12-knowledge-is-progress.md, 13-three-perspectives.md).
## Two things, and nothing else yet:
##   `chronicle`: the story event ids (Data.STORY_EVENTS) in the order they first happened, across runs. It is the
##     start of the Chronicle, the record of story moments a later run can read.
##   `knowledge`: the item ids the people have learned to gather. A future time loop rebuilds the map and
##     carries only this over, since knowledge is of kinds of things, never of places.
## absorb(state) merges a run (finished or in progress) into the profile: new ids are added at the end, ids
## already held keep their place, and absorbing the same run twice changes nothing.
## The profile is its own file (PATH), apart from the run save (scripts/run_save.gd): a run save holds no
## profile data and the profile holds no run data (no map, stockpile, buildings, people or research).
## A missing or corrupt file gives an empty profile and prints nothing. No faction words are spelled here.
## Nothing reads the profile yet: it does not change how a game starts or plays.

const VERSION := 1
const PATH := "user://profile.json"
const SECTIONS := ["chronicle", "knowledge"]

var chronicle: Array = []  # story ids, in the order they first happened
var knowledge: Array = []  # item ids, in the order they were first learned


## True while the profile holds nothing.
func is_empty() -> bool:
	return chronicle.is_empty() and knowledge.is_empty()


## Merge the run in `s` (a Sim) into the profile: its story ids and the items its people have learned.
func absorb(s) -> void:
	merge(s.story.events, s.people.learned_by.keys())


## Merge story ids and item ids given directly. Each id is kept once, new ones go on the end in the order
## given. Anything that is not a String is ignored.
func merge(story_ids: Array, item_ids: Array) -> void:
	_add_all(chronicle, story_ids)
	_add_all(knowledge, item_ids)


func knows(item: String) -> bool:
	return item in knowledge


func to_dict() -> Dictionary:
	return {"version": VERSION, "chronicle": chronicle.duplicate(), "knowledge": knowledge.duplicate()}


## Replace the profile with `d`. Anything that isn't a profile of this version gives an empty profile, and
## the stray entries in a good one (not strings, repeats) are dropped.
func from_dict(d) -> void:
	chronicle = []
	knowledge = []
	if not is_profile(d):
		return
	merge(d["chronicle"], d["knowledge"])


## True when `d` looks like a profile this code can read.
static func is_profile(d) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var version = d.get("version")
	if (typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT) or int(version) != VERSION:
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
