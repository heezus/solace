extends RefCounted
## Livewire stage 1: the net (design-system/23-livewire.md). Power Poles within Data.POLE_LINK tiles of one another join into
## a net; a machine (a building with `needs_power`) and an engine (a "power" building) within Data.POLE_REACH tiles of a pole are
## on that pole's net. A machine asks Data.MACHINE_ASK units while it would work, an engine gives its `gives` while it burns (a
## Water Wheel always), and a net that gives less than it is asked runs every machine on it slower by the ratio.
## Static, and works on the Sim passed in; the nets live on the Livewire block (`s.livewire.nets`, `net_at`). The structure is
## rebuilt when the buildings change (Buildings.road_rev), the units are counted again every tick. With no Power Pole standing
## all of it is a loop over an empty list, so nothing about the earlier eras changes.

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")


## One tick: rebuild the nets if the buildings changed, then count what each gives and is asked.
static func update(s) -> void:
	var lw = s.livewire
	if lw.net_rev != s.town.road_rev:
		_rebuild(s)
	for n in lw.nets:
		_count(s, n)


## The units an engine gives while it is going: a Water Wheel always, a fed one (a Boiler, a Generator) while it burns.
static func gives_now(b: Dictionary) -> int:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] != "power" or (def.get("fed", false) and b["burn"] <= 0.0):
		return 0
	return int(def.get("gives", 0))


## True when a machine asks for power: it has its crew and would work if it had it, and nothing holds it.
static func asking(s, b: Dictionary) -> bool:
	return not b["paused"] and Buildings.is_staffed(b) and not s.livewire.is_held(b) and s.town.wants_power(b)


## An engine on a net lights when the net is asked for more than the engines already burning give.
static func wants(s, b: Dictionary) -> bool:
	var n: Dictionary = s.livewire.net_at(b["pos"])
	return not n.is_empty() and n["asks"] > n["given"]


## An engine has just lit: its units count toward the net at once, so the next engine on it sees the shortfall closed.
static func lit(s, b: Dictionary) -> void:
	var n: Dictionary = s.livewire.net_at(b["pos"])
	if not n.is_empty():
		n["given"] += int(Data.BUILDINGS[b["type"]].get("gives", 0))


## The share of its speed a machine on a net runs at: 1 unless the net gives some power and less than it is asked for.
static func speed(n: Dictionary) -> float:
	if n.is_empty() or n["given"] <= 0 or n["asks"] <= n["given"]:
		return 1.0
	return float(n["given"]) / float(n["asks"])


## How many units a net is short by (0 when it gives enough).
static func shortfall(n: Dictionary) -> int:
	return maxi(n.get("asks", 0) - n.get("given", 0), 0)


## True when a net has a machine and an engine on it (the Goals panel's "a machine on a net").
static func working_net(s) -> bool:
	return s.livewire.nets.any(func(n): return not n["machines"].is_empty() and not n["engines"].is_empty())


## True when some net has at least two poles.
static func poles_joined(s) -> bool:
	return s.livewire.nets.any(func(n): return n["poles"].size() >= 2)


# --- The structure -------------------------------------------------------------------------------------------------


## Work out which poles are joined, and which machines and engines stand on which net. Nets and members are kept by tile, not by
## index, so a demolition between ticks never points them at the wrong building.
static func _rebuild(s) -> void:
	var lw = s.livewire
	lw.net_rev = s.town.road_rev
	lw.nets = []
	lw.net_of = {}
	var poles: Array = []
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "pole":
			poles.append(b["pos"])
	if poles.is_empty():
		return
	var group: Array = range(poles.size())
	for i in poles.size():
		for j in range(i + 1, poles.size()):
			if Vector2(poles[i]).distance_to(Vector2(poles[j])) <= Data.POLE_LINK:
				_join(group, i, j)
	var net_index := {}
	var pole_net: Array = []
	for i in poles.size():
		var root := _root(group, i)
		if not net_index.has(root):
			net_index[root] = lw.nets.size()
			lw.nets.append({"poles": [], "engines": [], "machines": [], "given": 0, "asks": 0})
		pole_net.append(net_index[root])
		lw.nets[net_index[root]]["poles"].append(poles[i])
		lw.net_of[poles[i]] = net_index[root]
	for b in s.town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var engine: bool = def["kind"] == "power"
		if not engine and not def.get("needs_power", false):
			continue
		var best := -1
		var best_d := Data.POLE_REACH + 0.001
		for i in poles.size():
			var d := Vector2(poles[i]).distance_to(Vector2(b["pos"]))
			if d < best_d:
				best = i
				best_d = d
		if best >= 0:
			lw.nets[pole_net[best]]["engines" if engine else "machines"].append(b["pos"])
			lw.net_of[b["pos"]] = pole_net[best]


static func _root(group: Array, i: int) -> int:
	while group[i] != i:
		i = group[i]
	return i


## Join the groups of poles i and j (the smaller root goes under the larger so the result never depends on the order).
static func _join(group: Array, i: int, j: int) -> void:
	var a := _root(group, i)
	var b := _root(group, j)
	if a != b:
		group[maxi(a, b)] = mini(a, b)


## Count a net's units: what its engines give while they burn, and what its machines ask.
static func _count(s, n: Dictionary) -> void:
	var given := 0
	for p in n["engines"]:
		if s.town.building_at.has(p):
			given += gives_now(s.town.buildings[s.town.building_at[p]])
	var asks := 0
	for p in n["machines"]:
		if s.town.building_at.has(p) and asking(s, s.town.buildings[s.town.building_at[p]]):
			asks += Data.MACHINE_ASK
	n["given"] = given
	n["asks"] = asks


# --- Words ---------------------------------------------------------------------------------------------------------


## What a building's card says about the net it stands on: a pole's net, a machine's share, an engine's units, or that it is on no
## net (only once Power Poles are learned, or for a Generator, which feeds nothing else). "" for the rest.
static func note(s, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var kind: String = def["kind"]
	var machine: bool = def.get("needs_power", false)
	if kind != "pole" and kind != "power" and not machine:
		return ""
	var n: Dictionary = s.livewire.net_at(b["pos"])
	if kind == "pole":
		for m in s.livewire.nets:
			if b["pos"] in m["poles"]:
				n = m
	if n.is_empty():
		if kind == "pole":
			return Data.POLE_ALONE
		return Data.NET_NONE if s.tech_tree.researched.has("power_poles") or def.get("radius", 1.0) <= 0.0 else ""
	if kind == "pole":
		return (
			Data.POLE_STATUS % [n["poles"].size(), n["machines"].size(), n["engines"].size(), n["given"], n["asks"]]
			+ _short_note(n)
		)
	var lines: Array = []
	if kind == "power":
		lines.append(Data.NET_ENGINE % int(def.get("gives", 0)))
	lines.append(Data.NET_LINE % [n["given"], n["asks"]])
	lines.append(_short_note(n).trim_prefix(". "))
	return ". ".join(lines.filter(func(l): return l != ""))


static func _short_note(n: Dictionary) -> String:
	if n["asks"] <= n["given"]:
		return ""
	if n["given"] <= 0:
		return ". " + Data.NET_SHORT_ALERT % shortfall(n) + ". " + Data.NET_DARK
	return ". " + Data.NET_RATIO % [shortfall(n), roundi(speed(n) * 100.0)]
