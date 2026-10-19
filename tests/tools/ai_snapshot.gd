extends RefCounted
## The AI player's eyes and hands (design-system/25-playtesting.md, part 2). `text` turns a Sim into what a person would read off
## the screen; `apply` runs the moves the player wrote through the same Sim commands the game's own buttons call, and says which
## it refused. Nothing here reaches past the public commands (place, demolish, research, gather_by_hand, the cards' answers), so
## the player cannot do anything a person could not. Read-only on everything else.

const Data = preload("res://scripts/data.gd")

const ERAS := ["Stone age", "Bronze Dawn", "Starfall", "Ironfall", "Livewire"]
const HELP := """MOVES: write moves_<n>.json, a list. Each move is one of
  {"do":"gather","x":3,"y":4}                      hand-gather the tile (a few harvests in a row: add "times":5)
  {"do":"build","type":"gatherers_hut","x":3,"y":4}  add "focus":"wood" for a hut's item; a road or field goes down one tile at a time
  {"do":"demolish","x":3,"y":4}
  {"do":"research","tech":"knapping"}
  {"do":"goal","tech":"bronze_dawn"}               set the research goal; the queue buys the techs on the way
  {"do":"season","choice":0}                       answer a Season card
  {"do":"moment","choice":0}                       answer a story moment card
  {"do":"wait","seconds":30}                       let the game run (the default, 15 seconds, is used when you send no wait)
Also write diary_<n>.md: two or three lines on what you wanted, and how it felt (bored, pleased, stuck, surprised).
Play to win the era you are in. You see only this page."""


## The era now, as the name a player would see.
static func era_name(s) -> String:
	var events: Array = s.story.events
	if Data.LIVEWIRE_BEGUN in events:
		return ERAS[4]
	if Data.IRONFALL_EVENT in events:
		return ERAS[3]
	if "star_falling" in events:
		return ERAS[2]
	return ERAS[1] if "bronze_dawn" in events else ERAS[0]


## The page the player reads: `n` is the decision number, `told` what the game said since the last page, `refused` the moves it refused.
static func text(s, n: int, told: Array, refused: Array) -> String:
	var out: Array = []
	out.append("DECISION %d · game time %s · %s" % [n, _clock(s.seasons.time), era_name(s)])
	var goals: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	out.append(
		(
			"GOAL (%d of %d done): %s"
			% [s.story.done_count(), goals.size(), goals[at]["text"] if at < goals.size() else "all met"]
		)
	)
	out.append_array(_cards(s))
	out.append("")
	out.append_array(_town(s))
	out.append("")
	out.append(_map(s))
	if not told.is_empty():
		out.append("\nTHE GAME SAID: " + " / ".join(told))
	if not refused.is_empty():
		out.append("\nREFUSED LAST TIME: " + " / ".join(refused))
	out.append("\n" + HELP)
	return "\n".join(out)


## Run each move; returns the refusals (empty when all were taken). A `wait` move is read by the caller, not here.
static func apply(s, moves: Array) -> Array:
	var refused: Array = []
	for m in moves:
		if typeof(m) != TYPE_DICTIONARY:
			refused.append("not a move: %s" % str(m))
			continue
		var at := Vector2i(int(m.get("x", -1)), int(m.get("y", -1)))
		var ok := true
		match str(m.get("do", "")):
			"gather":
				for i in clampi(int(m.get("times", 1)), 1, 20):
					ok = s.gather_by_hand(at) != "" and ok
			"build":
				ok = str(m.get("type", "")) in Data.BUILDINGS and s.place(str(m["type"]), at, str(m.get("focus", "")))
			"demolish":
				ok = not s.demolish(at).is_empty()
			"research":
				ok = str(m.get("tech", "")) in Data.TECHS and s.research(str(m["tech"]))
			"goal":
				ok = str(m.get("tech", "")) in Data.TECHS
				if ok:
					s.tech_tree.set_goal(str(m["tech"]))
			"season":
				ok = s.seasons.phase == "pending"
				if ok:
					s.seasons.choose(s, int(m.get("choice", 0)))
			"moment":
				ok = s.starfall.choose(int(m.get("choice", 0)))
			"wait":
				pass
			_:
				ok = false
		if not ok:
			refused.append(JSON.stringify(m))
	return refused


## Seconds the moves ask to wait (the longest `wait`), or `fallback` when none does.
static func wait_of(moves: Array, fallback: float) -> float:
	var out := 0.0
	for m in moves:
		if typeof(m) == TYPE_DICTIONARY and m.get("do", "") == "wait":
			out = maxf(out, clampf(float(m.get("seconds", fallback)), 1.0, 120.0))
	return out if out > 0.0 else fallback


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]


## The cards waiting on an answer.
static func _cards(s) -> Array:
	var out: Array = []
	if s.starfall.pending != "":
		var options: Array = s.starfall.pending_options()
		var labels: Array = []
		for i in options.size():
			labels.append("%d = %s" % [i, options[i]["label"]])
		var title: String = Data.MOMENTS[s.starfall.pending]["title"] if s.starfall.pending != "ending" else "The end"
		out.append("CARD WAITING (moment): %s. Answer with a moment move: %s" % [title, ", ".join(labels)])
	if s.seasons.phase == "pending":
		var def: Dictionary = Data.SEASONS[s.seasons.kind]
		var labels: Array = []
		for i in def["options"].size():
			labels.append("%d = %s (%s)" % [i, def["options"][i]["label"], def["options"][i]["note"]])
		out.append(
			(
				"CARD WAITING (season, answers itself with 0 after %d s): %s. %s Options: %s"
				% [
					int(Data.SEASON_AUTO),
					def["title"],
					def["text"] % [Data.SEASON_LENGTH, Data.PEOPLE["many"]],
					"; ".join(labels)
				]
			)
		)
	elif s.seasons.phase == "active":
		out.append("SEASON ON: %s, %d s left" % [Data.SEASONS[s.seasons.kind]["title"], int(s.seasons.left)])
	return out


## Food, people, stock, buildings, and what can be done now.
static func _town(s) -> Array:
	var out: Array = []
	var idle := 0
	for k in s.people.kith:
		if k["task"].is_empty():
			idle += 1
	out.append(
		(
			"FOOD: %d in store, lasts %s%s"
			% [
				roundi(s.economy.food_total()),
				_clock(minf(s.economy.seconds_of_food(), 3600.0)),
				", FAMINE" if s.economy.famine else ""
			]
		)
	)
	out.append("KITH: %d (%d idle), room for %d" % [s.people.kith.size(), idle, s.town.housing()])
	var stock: Array = []
	for id in s.economy.inv:
		if s.economy.inv[id] > 0:
			var cap: int = s.economy.caps.get(id, 0)
			stock.append(
				(
					"%s %d%s (%+.1f/s)"
					% [Data.ITEMS[id]["name"], s.economy.inv[id], "/%d" % cap if cap > 0 else "", s.economy.rate(id)]
				)
			)
	out.append("STOCK: " + (", ".join(stock) if not stock.is_empty() else "nothing"))
	var seen := {}
	for b in s.town.buildings:
		var line: String = "%s at (%d,%d)" % [Data.BUILDINGS[b["type"]]["name"], b["pos"].x, b["pos"].y]
		if b.get("focus", "") != "":
			line += " for " + b["focus"]
		if b.get("status", "") != "":
			line += ": " + str(b["status"]).left(60)
		if b.get("alert", "") != "":
			line += " [" + b["alert"] + "]"
		seen[line] = true
	out.append("BUILDINGS: " + ("; ".join(seen.keys()) if not seen.is_empty() else "none"))
	var can: Array = []
	for type in Data.BUILDINGS:
		if type != "camp" and s.town.unlocked(type):
			var cost: Array = []
			for id in s.town.price(type):
				cost.append("%d %s" % [s.town.price(type)[id], id])
			can.append("%s (%s)" % [type, ", ".join(cost)])
	out.append("BUILDABLE (type ids): " + ", ".join(can))
	var ready: Array = []
	for t in s.tech_tree.ready_list():
		var cost: Array = []
		for id in s.tech_tree.cost_of(t):
			cost.append("%d %s" % [s.tech_tree.cost_of(t)[id], id])
		ready.append("%s = %s (%s)" % [t, Data.TECHS[t]["name"], ", ".join(cost)])
	out.append("RESEARCHABLE NOW: " + (", ".join(ready) if not ready.is_empty() else "nothing you can pay for"))
	if s.tech_tree.goal != "":
		out.append("RESEARCH GOAL: %s, queue %s" % [s.tech_tree.goal, str(s.tech_tree.queue)])
	return out


## The seen part of the map, one character a tile; the legend comes after it.
static func _map(s) -> String:
	var legend := {}
	var used := {".": true}
	var rows: Array = []
	var built := {}
	for b in s.town.buildings:
		built[b["pos"]] = b["type"]
	for y in s.world.height:
		var row := ""
		for x in s.world.width:
			var p := Vector2i(x, y)
			if not s.fog.is_revealed(p):
				row += " "
				continue
			var key: String = (
				("B:" + built[p]) if built.has(p) else ("R" if s.world.roads.has(p) else s.world.tile_at(p))
			)
			if key == "grass" or key == "":
				row += "."
				continue
			if not legend.has(key):
				var base: String = key.substr(2).to_upper() if key.begins_with("B:") else key
				var ch := ""
				for c in base + "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ":
					if not used.has(c) and c != " ":
						ch = c
						break
				used[ch] = true
				legend[key] = ch
			row += legend[key]
		rows.append(row)
	var key_lines: Array = []
	for k in legend:
		key_lines.append("%s = %s" % [legend[k], k.substr(2) if k.begins_with("B:") else k])
	var ruler := "    "
	for x in s.world.width:
		ruler += str(x % 10)
	for y in rows.size():
		rows[y] = "%2d  %s" % [y, rows[y]]
	return (
		"MAP (x across, y down; the digits are each column's last digit; blank = unseen, . = open grass):\n%s\n%s\nLEGEND: %s"
		% [ruler, "\n".join(rows), ", ".join(key_lines)]
	)
