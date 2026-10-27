extends RefCounted
## What the Kith carry into this run from the ones before (Step 7, the Exodus: design-system/12-knowledge-is-progress.md).
## Knowledge of kinds, never of places: the techs already learned, the glyph marks already read, the Lumen sets whose echo is
## open. A first run carries nothing (`exodus` 0) and plays exactly as it always did. The carry is fixed when a run begins (it
## is the profile as it stood then, scripts/profile.gd) and is saved with the run, so a loaded run plays the same even if the
## profile has changed since. It is a block of the Sim that the run only reads, apart from `told`: the opening card was shown.

const Data = preload("res://scripts/data.gd")

var techs: Array = []  # tech ids learned in an earlier run: they cost a share of the study
var marks: Array = []  # glyph ids read in an earlier run: they show their word
var echoes: Array = []  # Lumen set ids read in an earlier run: that set's building is open from the start
var exodus := 0  # how many endings came before this run: 0 for a first run (the field keeps the Exodus's name)
var ending := ""  # the ending that began this run: "exodus", "cataclysm" or "loop", "" for a first run
var last_lean := ""  # the Lumen lean the run before ended with
var last_trust := 0.0  # the trust it ended with (the Time loop begins there)
var ruins: Array = []  # the Cataclysm's ruins, [{"pos": [x, y], "weight": n}] (scripts/ruins.gd)
var patches: Array = []  # and its dormant Bloom patches, [[x, y], ...]
var told := false  # the card that opens a run after an ending has been shown (scripts/notice_card.gd)


## True for a first run, which carries nothing.
func is_first() -> bool:
	return exodus == 0


## Take what the last ending handed on (Endings.handoff): the ending, the lean and trust it ended with, and the Cataclysm's ruins.
func set_handoff(h: Dictionary) -> void:
	ending = String(h.get("ending", ""))
	last_lean = String(h.get("lean", ""))
	last_trust = float(h.get("trust", 0.0))
	ruins = h.get("ruins", []).duplicate(true) if typeof(h.get("ruins")) == TYPE_ARRAY else []
	patches = h.get("patches", []).duplicate(true) if typeof(h.get("patches")) == TYPE_ARRAY else []


## The trust the strangers start at, given `base` (the first run's: a Cairn first makes them guests): the Time loop begins where the
## last run ended, a Cataclysm makes them arrive wary (no Cairn's welcome), any other run begins as a first run does.
func start_trust(base: float) -> float:
	match ending:
		"loop":
			return last_trust
		"cataclysm":
			return Data.TRUST_START_WARY
	return base


## True when the Lumen are welcomed as guests at the arrival: a Cairn first, and not after a Cataclysm.
func guests_welcome(cairn_first: bool) -> bool:
	return cairn_first and ending != "cataclysm"


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
	return {
		"techs": techs.duplicate(),
		"marks": marks.duplicate(),
		"echoes": echoes.duplicate(),
		"exodus": exodus,
		"ending": ending,
		"last_lean": last_lean,
		"last_trust": last_trust,
		"ruins": ruins.duplicate(true),
		"patches": patches.duplicate(true),
		"told": told,
	}


## Replace the carry with `d` (a run save without one gives a first run's).
func from_dict(d: Dictionary) -> void:
	techs = _strings(d.get("techs", []))
	marks = _strings(d.get("marks", []))
	echoes = _strings(d.get("echoes", []))
	exodus = maxi(int(d.get("exodus", 0)), 0)
	set_handoff(
		{
			"ending": d.get("ending", ""),
			"lean": d.get("last_lean", ""),
			"trust": d.get("last_trust", 0.0),
			"ruins": d.get("ruins"),
			"patches": d.get("patches")
		}
	)
	if ending == "" and exodus > 0:
		ending = "exodus"  # a run begun before the endings existed followed an Exodus
	told = bool(d.get("told", false))


static func _strings(list) -> Array:
	var out := []
	if typeof(list) != TYPE_ARRAY:
		return out
	for id in list:
		if typeof(id) == TYPE_STRING and not id in out:
			out.append(id)
	return out
