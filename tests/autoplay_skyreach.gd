extends "res://tests/autoplay_livewire.gd"
## The headless player for Skyreach (design-system/32-skyreach.md): from the end of Livewire in a second telling or later, to the
## third stage of the Skyreach. It plays on as the Livewire bot does (the metal works, the Wire Mills, the lamps that hold the Bloom)
## and adds what a player does for the sky: Signal Towers to cover the sectors facing the town, the first one finding the Skyreach's
## site; the shards chipped off the Strange Stone by hand; the goods of the towers and the three stages made and hauled; the Skyreach
## itself raised on its site and joined to the roads. It meets landfalls as it meets the tide: the Scorchers and lamps of the Livewire
## bot hold a patch off the town, and the Signal Towers' warning is why they stand where they do.
## play_skyreach(game, max_seconds) returns {"done" (the third stage stands), "seconds" (the clock then, -1 for never), "marks",
## "log"}; tests/tools/pace.gd prints it (`skyreach from=<a run dump from the end of Livewire>`).

const Skyreach = preload("res://scripts/skyreach.gd")

const TOWERS := 3  # Signal Towers the bot keeps: three sectors surveyed is the era's goal
const MEND_ENGINES := 4  # a mended net may bring the Generators to this many
const TOWER_NEAR := 8.0  # tiles from the Hearth a Signal Tower stands, as a rule
const TOWER_FAR := 13.0

var done_at := -1.0
var _sky_goals := {}


## Play `game` (a run from the end of Livewire, Skyward learned) through the Skyreach, or until `max_seconds` pass.
func play_skyreach(game: Sim, max_seconds: float) -> Dictionary:
	gate = SKYWARD
	goal_tech = SKYWARD
	attach(game)
	for tech in s.tech_tree.researched:
		known[tech] = true
	skyward_at = 0.0
	_drop_stranded_posts()
	_note_goals()
	while clock < max_seconds and done_at < 0.0:
		step(true)
	return {"done": done_at >= 0.0, "seconds": done_at, "marks": marks, "log": lines}


func _note_goals() -> void:
	super._note_goals()
	if not _sky_open():
		return
	for g in Data.SKYREACH["goals"]:
		if s.story.goals_done.has(g["id"]) and not _sky_goals.has(g["id"]):
			_sky_goals[g["id"]] = true
			marks[g["id"]] = clock
	if s.skyreach.site.x >= 0 and not marks.has("site_found"):
		marks["site_found"] = clock
	if done_at < 0.0 and s.story.has_event(Data.SKYREACH["done"]):
		done_at = clock
		marks["skyreach_done"] = clock


func _sky_open() -> bool:
	return s != null and s.story.has_event(Data.SKYREACH["begun"])


## True while the era is on and the Skyreach does not yet stand.
func _sky_working() -> bool:
	return _sky_open() and not s.story.has_event(Data.SKYREACH["done"])


# --- What the era needs --------------------------------------------------------


## The goods the towers still to raise and the stages still to deliver ask, by item.
func _sky_need(id: String) -> int:
	if not _sky_working():
		return 0
	var need := 0
	var tower_cost: int = Data.BUILDINGS["signal_tower"]["cost"].get(id, 0)
	need += maxi(TOWERS - _count("signal_tower"), 0) * tower_cost
	var tower := _skyreach()
	if tower.is_empty():
		need += Data.BUILDINGS["skyreach_tower"]["cost"].get(id, 0)
	var first_stage := 0 if tower.is_empty() else Skyreach.stage_of(tower)
	for stage in range(first_stage, 3):
		if stage == first_stage and not tower.is_empty() and float(tower.get("clock", -1.0)) >= 0.0:
			continue  # this stage is paid for and building
		var held: int = int(tower["inbuf"].get(id, 0)) if stage == first_stage and not tower.is_empty() else 0
		need += maxi(Data.SKYREACH["stage_cost"][stage].get(id, 0) - held, 0)
	return need


func _skyreach() -> Dictionary:
	for b in s.town.buildings:
		if b["type"] == Skyreach.TOWER:
			return b
	return {}


## Steel the Skyreach still lacks, while the era is on (the gate itself is long learned).
func _steel_left() -> int:
	if _sky_working():
		return maxi(_sky_need("steel") - _inv("steel"), 0)
	return super._steel_left()


## The goods the metal works must keep making for the era.
func _short_goods() -> Dictionary:
	var out := super._short_goods()
	if _sky_working():
		for id in ["iron", "coal", "iron_ore", "steel", "copper", "wire"]:
			if _gate_short(id) > 0:
				out[id] = true
	return out


func _route_cost(id: String) -> int:
	return super._route_cost(id) + _sky_need(id)


func _goal_wants(want: Dictionary) -> void:
	super._goal_wants(want)
	for id in ["shard", "stone", "brick", "rope", "copper"]:
		var need := _sky_need(id)
		if need > 0:
			want[id] = want.get(id, 0) + need


func _pick_tile() -> Vector2i:
	if _sky_working() and _sky_need("shard") > _inv("shard") and Hands.chips_shard(s):
		var stone := _nearest_tile("shard", s.world.camp_pos)
		if stone.x >= 0:
			return stone  # the shards are quick to chip and the era waits on them: they come before the rest
	return super._pick_tile()


# --- Building --------------------------------------------------------------------


func _build_livewire() -> bool:
	if _sky_working() and _build_sky():
		return true
	return super._build_livewire()


func _build_sky() -> bool:
	_look_at_stone()
	if _mend_wire_power():
		return true
	if s.skyreach.site.x >= 0 and _skyreach().is_empty() and _place_skyreach():
		return true
	if _count("signal_tower") < TOWERS and s.town.unlocked("signal_tower") and _place_signal():
		return true
	return false


## The Bloom eats poles and engines. While the Skyreach still wants Wire and a Wire Mill stands with no engine on its net, a player
## puts an engine back beside that net's poles (or a pole beside a mill that fell off every net). Four engines at most.
func _mend_wire_power() -> bool:
	if _sky_need("wire") <= _inv("wire") or _count("generator") >= MEND_ENGINES:
		return false
	for b in s.town.buildings:
		if b["type"] != "wire_mill" or b["paused"]:
			continue
		var at: Vector2i = b["pos"]
		if s.livewire.net_of.has(at):
			var net: Dictionary = s.livewire.nets[s.livewire.net_of[at]]
			if not net["engines"].is_empty():
				continue
			var poles: Array = net["poles"]
			var near := func(p):
				var best := INF
				for q in poles:
					best = minf(best, Vector2(p).distance_to(Vector2(q)))
				return -INF if best > Data.POLE_REACH else -best
			if s.town.unlocked("generator") and _place_best("generator", near):
				lines.append("%5.0f s    + Generator beside the cut net of the Wire Mill at %s" % [clock, at])
				return true
		elif s.town.unlocked("power_pole"):
			var close := func(p):
				return (
					-Vector2(p).distance_to(Vector2(at))
					if Vector2(p).distance_to(Vector2(at)) <= Data.POLE_REACH
					else -INF
				)
			if _place_best("power_pole", close):
				lines.append("%5.0f s    + Power Pole beside the Wire Mill at %s" % [clock, at])
				return true
	return false


## Click the Strange Stone once, as a player does, so that a hold on it chips Shards from then on.
func _look_at_stone() -> void:
	var p: Vector2i = s.world.shard_pos
	if s.shard_seen or not s.world.in_bounds(p):
		return
	if s.fog.is_revealed(p):
		s.gather_by_hand(p)
		lines.append("%5.0f s    reads the Strange Stone" % clock)
	else:
		_explore_to(p)  # roads push the fog back toward the stone


## The Skyreach on its site, once it can be afforded.
func _place_skyreach() -> bool:
	if not s.town.unlocked("skyreach_tower") or not s.economy.can_afford(s.town.price("skyreach_tower")):
		return false
	var site: Vector2i = s.skyreach.site
	if s.town.placement_error("skyreach_tower", site) != "":
		return false
	if not s.place("skyreach_tower", site):
		return false
	lines.append("%5.0f s    + Skyreach at %s" % [clock, site])
	return true


## A Signal Tower in the sector, among those not yet surveyed, that faces the most of the town; at the right distance from the Hearth.
func _place_signal() -> bool:
	if not s.economy.can_afford(s.town.price("signal_tower")):
		return false
	var camp: Vector2i = s.world.camp_pos
	var weight := {}
	for b in s.town.buildings:
		var sector := Skyreach.sector_of(camp, b["pos"])
		weight[sector] = weight.get(sector, 0) + 1
	var surveyed := s.skyreach.survey(s)
	var first := _count("signal_tower") == 0
	for reach_out in [TOWER_FAR, TOWER_FAR * 2.0]:  # a crowded Hearth has no open ground in the near ring: look further out
		var placed := _place_best(
			"signal_tower",
			func(p):
				var sector := Skyreach.sector_of(camp, p)
				var far := Vector2(p).distance_to(Vector2(camp))
				if surveyed.has(sector) or far < TOWER_NEAR or far > reach_out:
					return -INF
				var near := absf(far - (TOWER_NEAR + 1.0))
				if first:  # the first tower finds the Skyreach's site in its own sector: put it where the Bloom is furthest
					return float(s.skyreach.clear_of_bloom(s, p)) * 10.0 - near
				return float(weight.get(sector, 0)) * 10.0 - near
		)
		if placed:
			return true
	return false
