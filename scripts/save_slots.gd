extends RefCounted
## The save slots: COUNT run saves, each its own file (user://run_slot_1.json and on). A slot file is a run save exactly as
## RunSave writes it, with one more top-level key, "meta" (the era, minutes played, Kith and when it was saved), so a slot
## can be listed without restoring it and RunSave.VERSION is unchanged: RunSave reads a slot file as it reads any save.
## The one save of older versions (user://run.json) is moved into the first empty slot the first time slots are listed.
## There is no autosave: a slot is written only when the player picks it in the pause menu. Static; every call takes the
## directory (`dir`) the files live in, so tests can use a folder of their own.

const Data = preload("res://scripts/data.gd")
const RunSave = preload("res://scripts/run_save.gd")

const COUNT := 5
const DIR := "user://"


## The file of slot `slot` (1 to COUNT).
static func path(slot: int, dir := DIR) -> String:
	return "%srun_slot_%d.json" % [dir, slot]


## The file the single save used before slots.
static func legacy_path(dir := DIR) -> String:
	return dir + RunSave.PATH.get_file()


## What a list of slots needs to know about the run saved in `d` (a run dump): {"era", "minutes", "kith", "saved_at"}.
static func meta_of(d: Dictionary) -> Dictionary:
	var game: Dictionary = d["game"]
	var era: String = Data.ERA_STONE
	if game.get("won", false):
		era = Data.ERA_BRONZE
	if game.get("starfall", {}).get("stage", "") != "":
		era = Data.ERA_STARFALL
	return {
		"era": era,
		"minutes": int(float(d["economy"].get("flows", {}).get("clock", 0.0)) / 60.0),
		"kith": d["kith"].get("kith", []).size(),
		"saved_at": int(Time.get_unix_time_from_system()),
	}


## Write the run in `s` into slot `slot`. False when the file could not be written.
static func save(s, slot: int, dir := DIR) -> bool:
	if slot < 1 or slot > COUNT:
		return false
	return _write(RunSave.dump(s), slot, dir)


static func _write(d: Dictionary, slot: int, dir: String) -> bool:
	var out := d.duplicate()
	out["meta"] = meta_of(d)
	var file := FileAccess.open(path(slot, dir), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(RunSave.to_json(out))
	file.close()
	return true


## The run in slot `slot` as a dump, or {} when the slot is empty or its file is not a run save.
static func read(slot: int, dir := DIR) -> Dictionary:
	if slot < 1 or slot > COUNT or not FileAccess.file_exists(path(slot, dir)):
		return {}
	var d := RunSave.from_json(FileAccess.get_file_as_string(path(slot, dir)))
	return d if RunSave.is_run_save(d) else {}


## Read slot `slot` into `s`. False, with `s` untouched, when the slot is empty or unreadable.
static func load_into(s, slot: int, dir := DIR) -> bool:
	var d := read(slot, dir)
	return not d.is_empty() and RunSave.restore(s, d)


## The meta of slot `slot` ({} when it holds nothing readable). A save without one gets it worked out from the run.
static func meta(slot: int, dir := DIR) -> Dictionary:
	var d := read(slot, dir)
	if d.is_empty():
		return {}
	var m = d.get("meta")
	return m if typeof(m) == TYPE_DICTIONARY and m.has("era") else meta_of(d)


## One line about slot `slot`: "Starfall, 42 min, 7 Kith", or "empty".
static func summary(slot: int, dir := DIR) -> String:
	var m := meta(slot, dir)
	if m.is_empty():
		return Data.SLOT_EMPTY
	return Data.SLOT_SUMMARY % [m["era"], int(m["minutes"]), int(m["kith"])]


## The slots that hold a save, in order, after moving a pre-slot save in (see migrate).
static func filled(dir := DIR) -> Array:
	migrate(dir)
	var out := []
	for slot in range(1, COUNT + 1):
		if not read(slot, dir).is_empty():
			out.append(slot)
	return out


## The slot saved most recently (0 when there is none): what Continue loads.
static func latest(dir := DIR) -> int:
	var best := 0
	var best_at := -1
	for slot in filled(dir):
		var at := int(meta(slot, dir).get("saved_at", 0))
		if at > best_at:
			best = slot
			best_at = at
	return best


## Move the save of older versions (user://run.json) into the first empty slot, so nobody loses a run, and remove the old
## file. Does nothing without one, with a file that is not a run save, or when every slot is taken. Returns the slot used
## (0 for none).
static func migrate(dir := DIR) -> int:
	var old := legacy_path(dir)
	if not FileAccess.file_exists(old):
		return 0
	var d := RunSave.from_json(FileAccess.get_file_as_string(old))
	if not RunSave.is_run_save(d):
		return 0
	for slot in range(1, COUNT + 1):
		if read(slot, dir).is_empty() and not FileAccess.file_exists(path(slot, dir)):
			if _write(d, slot, dir):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(old))
				return slot
			return 0
	return 0
