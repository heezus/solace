extends RefCounted
## The Sky block: the new light over the second era. Sky Watch names it the Wanderer. While a Watchtower stands the
## Kith watch for it and log a sighting every Data.SIGHTING_SECONDS (flavor in the event log: hopeful at first, then
## less so). Every tech of the era the Kith work out brings the light nearer (`approach`), and Star Charts draws its
## path. It only reads the Research and Buildings blocks and writes nothing of theirs. What a sighting says is in Data,
## so another faction can see something else. Sim owns one, reached as `sim.sky`.
## Signal: sighted(message) fires with each sighting's line (the owner shows it).

signal sighted(message: String)

const Data = preload("res://scripts/data.gd")
const Rules = preload("res://scripts/rules.gd")
const Research = preload("res://scripts/research.gd")
const Buildings = preload("res://scripts/buildings.gd")

var sightings := 0  # how many sightings the Kith have logged
var clock := 0.0  # seconds since the last one, counted only while a Watchtower stands
var _research: Research
var _town: Buildings


func _init(research: Research, town: Buildings) -> void:
	_research = research
	_town = town


## True once Sky Watch has named the light: from then on it is on show.
func named() -> bool:
	return _research.unlocked("sky_watch")


## True once Star Charts has drawn the light's path.
func charted() -> bool:
	return _research.unlocked("star_charts")


## True once a Watchtower stands: there is somewhere to watch from.
func watched() -> bool:
	for b in _town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "tower":
			return true
	return false


## 0 to 1: how near the Wanderer is. Each tech of the era the Kith have worked out is a step toward it, and the last
## one, The Falling Star, is the whole way. 0 before Sky Watch has named it.
func approach() -> float:
	if not named():
		return 0.0
	var techs := Rules.era_techs(2)
	var done := 0
	for t in techs:
		if _research.unlocked(t):
			done += 1
	return float(done) / float(techs.size())


## Which of the three moods of Data.WANDERER_SIGHTINGS the Kith are in: 0 hopeful, 1 uneasy, 2 afraid.
func mood() -> int:
	return mini(int(approach() * Data.WANDERER_SIGHTINGS.size()), Data.WANDERER_SIGHTINGS.size() - 1)


## Research.tech_researched (connected by the owner): Sky Watch names the light, and the Kith say so at once.
func on_tech_researched(tech: String) -> void:
	if tech == "sky_watch":
		sighted.emit(Data.WANDERER_NAMED_LINE)


## One tick: while a Watchtower stands the clock runs, and each SIGHTING_SECONDS the Kith log a sighting.
func tick(delta: float) -> void:
	if not named() or not watched():
		return
	clock += delta
	if clock < Data.SIGHTING_SECONDS:
		return
	clock -= Data.SIGHTING_SECONDS
	var lines: Array = Data.WANDERER_SIGHTINGS[mood()]
	sighted.emit(lines[sightings % lines.size()])
	sightings += 1


func to_dict() -> Dictionary:
	return {"sightings": sightings, "clock": clock}


func from_dict(d: Dictionary) -> void:
	sightings = int(d.get("sightings", 0))
	clock = float(d.get("clock", 0.0))
