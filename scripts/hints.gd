extends RefCounted
## The first-time hints: one short note the first time a new mechanic matters. The game scene (scripts/main.gd) asks `update` once a
## frame; the first hint whose moment has come (Data.HINT_ORDER) shows as a sticky toast of kind "hint" until it is clicked away.
## Each shows once ever: its id goes into the profile (scripts/profile.gd) the moment it shows, so a dismissed hint, a loaded game
## and a new run never see it again. The switch is HintSettings (the pause menu's "Hints"). One hint at a time: the next waits for
## the one on screen to go. Only the game scene makes one of these, so the scripted bots and the AI player never see a hint;
## the tools that build the game scene headless already set CutscenePlayer.suppress, and hints follow it.
## The moments are read from the Sim and change nothing in it.

const Data = preload("res://scripts/data.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const GrowthNote = preload("res://scripts/growth_note.gd")
const HintSettings = preload("res://scripts/hint_settings.gd")
const Messages = preload("res://scripts/messages.gd")
const Profile = preload("res://scripts/profile.gd")
const Sight = preload("res://scripts/sight.gd")
const Ui = preload("res://scripts/ui.gd")

static var profile_path := Profile.PATH

var messages: Messages
var _seen: Array = []  # hint ids already shown, from the profile
var _held := {}  # hint id -> seconds its moment has held without a break (the ones that wait)
var _sight := Sight.new()
var _sight_clock := 0.0


## A hints maker for the toasts in `queue`, knowing the hints the profile says were shown. Null when the tools have set
## CutscenePlayer.suppress.
static func attach(queue: Messages) -> Variant:
	if CutscenePlayer.suppress:
		return null
	var hints := new()
	hints.messages = queue
	var profile := Profile.new()
	profile.load_file(profile_path)
	hints._seen = profile.hints.duplicate()
	return hints


## True when hint `id` has been shown in this or an earlier run.
func has_shown(id: String) -> bool:
	return id in _seen


## One frame: show the first waiting hint whose moment has come, if the switch is on and none is on screen.
func update(s, delta: float) -> void:
	if not HintSettings.on() or messages.active.any(func(m): return m["kind"] == Data.HINT_KIND):
		return
	_sight_clock -= delta
	for id in Data.HINT_ORDER:
		if id in _seen:
			continue
		if _moment(s, id, delta):
			_show(s, id)
			return


func _show(s, id: String) -> void:
	_seen.append(id)
	Profile.note_hint(id, profile_path)
	var text: String = Data.HINTS[id]
	if id == "births_wait":
		text = Data.NOTE_BIRTHS_WAIT % [s.people.idle_now, Data.PEOPLE["many"]]
	messages.push(text, 0.0, true, Data.HINT_KEY + id, Data.HINT_KIND)


## True when the moment hint `id` waits for has come. A moment that must last (hands short, a gap) counts the seconds it has held.
func _moment(s, id: String, delta: float) -> bool:
	match id:
		"hut":
			return _any_building(s, func(b): return Data.BUILDINGS[b["type"]]["kind"] == "gatherer")
		"hauler_wait":
			return _any_building(s, func(b): return b["alert"] == "Full: waiting for a hauler")
		"short_hands":
			return _lasts(id, Ui.job_slots(s) > Ui.jobs_filled(s) and Ui.idle_kith(s) <= 0, delta, Data.HINT_SHORT_FOR)
		"store_full":
			for good in s.economy.caps:
				if s.economy.inv.get(good, 0) > 0 and s.economy.is_full(good):
					return true
			return false
		"strain":
			return s.seasons.phase == "active"
		"births_wait":
			return not s.economy.starving and s.people.kith.size() < s.town.housing() and GrowthNote.births_wait_now(s)
		"gap":
			return _lasts(id, _red_gap(s), delta, Data.HINT_GAP_FOR)
		"mine":
			return _any_building(s, func(b): return b["type"] == "mine")
		"storehouse":
			return _any_building(s, func(b): return b["type"] == "storehouse")
	return false


func _any_building(s, test: Callable) -> bool:
	for b in s.town.buildings:
		if test.call(b):
			return true
	return false


## Seconds in a row `now` has been true; true once that reaches `needed`.
func _lasts(id: String, now: bool, delta: float, needed: float) -> bool:
	if not now:
		_held.erase(id)
		return false
	_held[id] = _held.get(id, 0.0) + delta
	return _held[id] >= needed


## A red gap on the map, as Sight would show it (read about once a second).
func _red_gap(s) -> bool:
	if _sight_clock <= 0.0:
		_sight_clock = 1.0
		_sight.gather(s)
	return _sight.gaps.any(func(g): return g["loud"])
