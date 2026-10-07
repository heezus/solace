extends RefCounted
## What a home says about itself, in words: the needs lines for its card, the hover text on the map, the one-line state, and the
## settlement readout on the Homes tab that tells the player why homes are stalled. Static and pure: it reads the Sim and
## changes nothing. The numbers are in scripts/homes.gd and Data.HOME_TIERS; the words in Data (words.gd).

const Data = preload("res://scripts/data.gd")
const Homes = preload("res://scripts/homes.gd")
const Ui = preload("res://scripts/ui.gd")


## The needs of home `b` as lines, each {"text", "ok"}: the food kinds, then each good.
static func need_lines(s, b: Dictionary) -> Array:
	var st := Homes.status(s, b)
	var out: Array = []
	var names: Array = st["food_kinds"].map(func(id): return Data.ITEMS[id]["name"])
	var foods: String = Data.HOME_NEED_FOODS % [st["foods_have"], st["foods_need"]]
	if not names.is_empty():
		foods += " (%s)" % ", ".join(names)
	out.append({"text": foods, "ok": st["foods_have"] >= st["foods_need"]})
	for g in st["goods"]:
		out.append(
			{
				"text": Data.HOME_NEED_GOOD % [Data.ITEMS[g["item"]]["name"], g["have"], g["need"]],
				"ok": g["have"] >= g["need"]
			}
		)
	return out


## The state in a line: needs met, or what is missing, or the scaffold's progress, or that this is the top.
static func state_line(s, b: Dictionary) -> String:
	var tier := Homes.tier_of(b)
	var top: bool = tier >= Data.HOME_TIERS.size() - 1
	if b["site"] == "building":
		return Data.HOME_BUILDING % [Data.HOME_NAMES[tier + 1], roundi(Homes.build_of(b) - b["site_t"])]
	if b["site"] == "waiting":
		return Data.HOME_HAULING % [Data.HOME_NAMES[tier + 1], roundi(Homes.fill(b) * 100.0)]
	var st := Homes.status(s, b)
	if not st["met"]:
		return Data.HOME_STALLED % ", ".join(st["missing"])
	if top:
		return Data.HOME_TOP
	var why := Homes.stalled(s, b)
	if why != "":
		return Data.HOME_HELD % why
	if b["met"] < Homes.after_of(b):
		return Data.HOME_COUNTING % [roundi(b["met"]), roundi(Homes.after_of(b))]
	return Data.HOME_READY


## "Houses 4" or "Houses 3 now, 4 once its needs are met".
static func housing_line(b: Dictionary) -> String:
	var full: int = Homes.housing_of(b)
	if b["content"] or full == Data.HOME_TIERS[0]["housing"]:
		return Data.HOME_HOUSES % full
	return Data.HOME_HOUSES_LAPSED % [Data.HOME_TIERS[0]["housing"], full]


## What the next tier will cost, "Next: Homestead for 20 Wood, 14 Clay", or "" at the top.
static func next_line(b: Dictionary) -> String:
	var up := Homes.materials(b)
	if up.is_empty():
		return ""
	return Data.HOME_NEXT % [Data.HOME_NAMES[Homes.tier_of(b) + 1], Ui.cost_text(up)]


## The hover on a home: its name and tier, the state, and its needs.
static func hover(s, b: Dictionary) -> String:
	var lines: Array = [Homes.name_of(b), state_line(s, b)]
	for l in need_lines(s, b):
		lines.append(("[ok] " if l["ok"] else "[needs] ") + l["text"])
	lines.append(housing_line(b))
	return "\n".join(lines)


## The Homes tab's readout: how many homes at each tier, and why the stalled ones are: "9 homes: 2 Dwellings, 3 Homesteads,
## 4 Longhouses. 3 stalled: one more kind of food in stock". "" with no homes.
static func readout(s) -> String:
	var counts := [0, 0, 0]
	var why := {}
	var total := 0
	for b in s.town.buildings:
		if not Homes.is_home(b):
			continue
		total += 1
		counts[Homes.tier_of(b)] += 1
		var st := Homes.status(s, b)
		if not st["met"]:
			var reason := ", ".join(st["missing"])
			why[reason] = why.get(reason, 0) + 1
	if total == 0:
		return ""
	var parts: Array = []
	for tier in counts.size():
		if counts[tier] > 0:
			parts.append("%d %s" % [counts[tier], Data.HOME_PLURALS[tier]])
	var out: String = Data.HOME_READOUT % [total, ", ".join(parts)]
	if why.is_empty():
		return out + " " + Data.HOME_ALL_MET
	var worst := ""
	var worst_n := 0
	var stalled := 0
	for reason in why:
		stalled += why[reason]
		if why[reason] > worst_n:
			worst = reason
			worst_n = why[reason]
	return out + " " + Data.HOME_READOUT_STALLED % [stalled, worst]
