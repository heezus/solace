extends RefCounted
## What the Kith carry into this run from the ones before (Step 7, the Exodus: design-system/12-knowledge-is-progress.md).
## Knowledge of kinds, never of places: the techs already learned, the glyph marks already read, the Lumen sets whose echo is
## open. A first run carries nothing (`exodus` 0) and plays exactly as it always did. The carry is fixed when a run begins (it
## is the profile as it stood then, scripts/profile.gd) and is saved with the run, so a loaded run plays the same even if the
## profile has changed since. It is a block of the Sim, but only reads: nothing in a run changes it.

const Data = preload("res://scripts/data.gd")

var techs: Array = []  # tech ids learned in an earlier run: they cost half the study
var marks: Array = []  # glyph ids read in an earlier run: they show their word
var echoes: Array = []  # Lumen set ids read in an earlier run: that set's building is open from the start
var exodus := 0  # which Exodus this run is: 0 for a first run


## True for a first run, which carries nothing.
func is_first() -> bool:
	return exodus == 0


func knows_tech(tech: String) -> bool:
	return tech in techs


func knows_mark(glyph: String) -> bool:
	return glyph in marks


func has_echo(set_id: String) -> bool:
	return set_id in echoes


## What the run in `s` (a Sim) would carry on: {"techs", "marks", "echoes"}, each in a fixed order. The techs are the ones
## researched, the marks are those of every set read, and an echo is a read set that has a Lumen building (Data.ROAD_ORDER).
static func earned(s) -> Dictionary:
	var techs_out := []
	for tech in Data.TECHS:
		if s.tech_tree.researched.has(tech):
			techs_out.append(tech)
	var marks_out := []
	var echoes_out := []
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if not s.starfall.locked.has(gset["id"]):
			continue
		marks_out.append_array(gset["glyphs"])
		if gset["id"] in Data.ROAD_ORDER:
			echoes_out.append(gset["id"])
	return {"techs": techs_out, "marks": marks_out, "echoes": echoes_out}


func to_dict() -> Dictionary:
	return {"techs": techs.duplicate(), "marks": marks.duplicate(), "echoes": echoes.duplicate(), "exodus": exodus}


## Replace the carry with `d` (a run save without one gives a first run's).
func from_dict(d: Dictionary) -> void:
	techs = _strings(d.get("techs", []))
	marks = _strings(d.get("marks", []))
	echoes = _strings(d.get("echoes", []))
	exodus = maxi(int(d.get("exodus", 0)), 0)


static func _strings(list) -> Array:
	var out := []
	if typeof(list) != TYPE_ARRAY:
		return out
	for id in list:
		if typeof(id) == TYPE_STRING and not id in out:
			out.append(id)
	return out
