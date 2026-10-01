extends RefCounted
## Map overlays drawn over the tiles and buildings: demolish hover and rubble, flow arrows for the
## selected workshop, status pills pinned under buildings, the settlement ring, and the fog.
## Static: each takes the CanvasItem to draw on (the map) and the Sim.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")

const TILE := 48.0  # map px per tile at the default zoom
const OUTLINE: Color = Art.OUTLINE
const ALERT: Color = Ui.BAD
const KITH: Color = Ui.KITH
const RUBBLE_TIME := 0.9


static func rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(p) * TILE, Vector2(TILE, TILE))


static func center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * TILE


## What a building at p covers on the map: its tile, or for the Hearth a 2x2 block centred on its tile. This is
## only how it is drawn: the Hearth still stands on one tile, so nothing about placement or walking changes.
static func footprint(s, p: Vector2i) -> Rect2:
	if s.town.built_type(p) == "camp":
		return rect(p).grow(TILE * 0.5)
	return rect(p)


## The pill a demolish click would answer: what comes back and who goes idle.
static func demolish_text(s, p: Vector2i) -> String:
	var type: String = s.town.built_type(p)
	if type == "":
		return ""
	var def: Dictionary = Data.BUILDINGS[type]
	if def["kind"] == "camp":
		return "The Hearth stays · it's the heart of the settlement"
	var refund := Rules.refund_of(type)
	var text := (
		"Demolish %s · %s"
		% [def["name"], ("get back " + Ui.cost_text(refund)) if not refund.is_empty() else "nothing back"]
	)
	if s.town.building_at.has(p) and s.town.buildings[s.town.building_at[p]]["worker"] >= 0:
		var b: Dictionary = s.town.buildings[s.town.building_at[p]]
		text += " · %s goes idle" % s.people.title_of(s.people.kith[b["worker"]])
	return text


## Demolish mode: a red frame and wash with a white X over whatever is there, and the pill above it.
static func demolish_hover(ci: CanvasItem, s, p: Vector2i) -> void:
	var r := rect(p)
	var type: String = s.town.built_type(p)
	if type == "" or Data.BUILDINGS[type]["kind"] == "camp":
		ci.draw_rect(r.grow(-2), Color(1, 1, 1, 0.5), false, 2.0)
		if type != "":
			Art.pill(ci, r.get_center() - Vector2(0, TILE * 1.2), demolish_text(s, p), Ui.TEXT, OUTLINE, 14)
		return
	ci.draw_rect(r, Color(ALERT, 0.35))
	var tex := Art.sprite("demolish_hover")
	if tex != null:
		ci.draw_texture_rect(tex, r, false)
	else:
		for d in [Vector2(1, 1), Vector2(1, -1)]:
			var a: Vector2 = r.get_center() - d * 9.0
			var b: Vector2 = r.get_center() + d * 9.0
			ci.draw_line(a, b, OUTLINE, 7.0)
			ci.draw_line(a, b, Color.WHITE, 4.0)
	ci.draw_rect(r, ALERT, false, 3.0)
	Art.pill(ci, r.get_center() - Vector2(0, TILE * 1.2), demolish_text(s, p), ALERT, Ui.TEXT, 14)


## Torn-down buildings leave rubble for a moment: `list` holds {"pos", "t"}.
static func rubble(ci: CanvasItem, list: Array) -> void:
	var tex := Art.sprite("rubble")
	for r in list:
		var a := clampf(1.0 - r["t"] / RUBBLE_TIME, 0.0, 1.0)
		var box := rect(r["pos"])
		if tex != null:
			ci.draw_texture_rect(tex, box, false, Color(1, 1, 1, a))
			continue
		for i in 5:
			var c: Vector2 = box.get_center() + Vector2.from_angle(i * 1.3) * (4.0 + i * 1.5)
			ci.draw_circle(c, 4.0, Color(OUTLINE, a))
			ci.draw_circle(c, 2.8, Color(Color("9a8c7a"), a))


## A curved path from a to b that bows to one side, so the in and out arrows don't overlap.
static func bow(a: Vector2, b: Vector2, side: float) -> PackedVector2Array:
	var mid := (a + b) / 2.0 + (b - a).orthogonal().normalized() * side * clampf(a.distance_to(b) * 0.25, 12.0, 48.0)
	var pts := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	return pts


## One flow arrow: a 7px outline line with 4px item-colored dots (2 on, 7 off) moving from a to b,
## an arrowhead at b and a label at the bend.
static func flow_arrow(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, text: String, time: float) -> void:
	var pts := bow(a, b, 1.0)
	ci.draw_polyline(pts, OUTLINE, 7.0, true)
	for part in Art.dash_pattern(pts, 2.0, 7.0, -time * 24.0):
		ci.draw_polyline(part, col, 4.0, true)
	var tip := pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 4]).normalized()
	var head := PackedVector2Array(
		[tip, tip - dir * 11.0 + dir.orthogonal() * 7.0, tip - dir * 11.0 - dir.orthogonal() * 7.0]
	)
	ci.draw_colored_polygon(head, col)
	ci.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), OUTLINE, 1.5)
	var mid := pts[10]
	Art.outlined_text(ci, mid + Vector2(-16, -8), text, 13, col.lightened(0.3))


## Selecting a workshop: its inputs flow out from the stockpile, its outputs flow back.
static func flow_arrows(ci: CanvasItem, s, b: Dictionary, time: float) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] != "processor":
		return
	var here := center(b["pos"])
	var depot := center(s.people.nearest_depot(b["pos"]))
	if here.distance_to(depot) < TILE:
		return
	var k := 0
	for id in def["in"]:
		var off := Vector2(0, 6 * k)
		flow_arrow(
			ci,
			depot + off,
			here + off,
			Data.ITEMS[id]["color"],
			"%d %s" % [def["in"][id], Data.ITEMS[id]["name"]],
			time
		)
		k += 1
	for id in def["out"]:
		flow_arrow(ci, here, depot, Data.ITEMS[id]["color"], "%d %s" % [def["out"][id], Data.ITEMS[id]["name"]], time)


## The word on an alert's pill: "Hungry: no food" says "Hungry", "Idle: no free Kith" says "Idle". The whole
## alert is still in the building's status, in its card and on hover.
static func pill_text(alert: String) -> String:
	return alert.split(":")[0]


## Blocked buildings (hungry, no power, no road...) wear a 16 px alert-red badge on their lower right corner. No
## text on the map: the words are in the Info panel while the mouse is over the building.
static func alert_badges(ci: CanvasItem, s) -> void:
	var font := ThemeDB.fallback_font
	for b in s.town.buildings:
		if b["alert"] == "":
			continue
		var r := rect(b["pos"])
		var at := r.end - Vector2(6.0, 6.0) * Art.ui_k
		var radius := 8.0 * Art.ui_k
		ci.draw_circle(at, radius, ALERT)
		ci.draw_arc(at, radius, 0, TAU, 24, Ui.LINE, maxf(2.0 * Art.ui_k, 1.0), true)
		var px := roundi(14.0 * Art.ui_k)
		var wide := font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(font, at + Vector2(-wide / 2.0, px * 0.36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ui.TEXT)


## The Hearth's reach: a 2 px dashed cream line at 40% opacity, labelled "Build range", drawn only while a Dwelling
## is being placed or the mouse is over the Hearth. While placing, the good empty spots inside are dashed too.
static func settlement_ring(ci: CanvasItem, s, placing_home: bool, over_hearth: bool) -> void:
	if not (placing_home or over_hearth):
		return
	var c := center(s.world.camp_pos)
	var radius: float = (Data.HEARTH_RADIUS + 0.5) * TILE
	var k := Art.ui_k
	var line := Color(Ui.TEXT, 0.4)
	Art.dashed_circle(ci, c, radius, line, 2.0 * k, 10.0 * k, 7.0 * k)
	if placing_home:
		for y in range(-int(Data.HEARTH_RADIUS), int(Data.HEARTH_RADIUS) + 1):
			for x in range(-int(Data.HEARTH_RADIUS), int(Data.HEARTH_RADIUS) + 1):
				var p: Vector2i = s.world.camp_pos + Vector2i(x, y)
				if s.world.in_bounds(p) and s.town.placement_error("dwelling", p) == "":
					Art.dashed_rect(ci, rect(p).grow(-6), Color(Ui.TEXT, 0.5), 2.0 * k, 4.0 * k, 3.0 * k)
	Art.pill(ci, c - Vector2(0, radius + 12.0 * k), "Build range", Ui.TEXT, Ui.LINE, 14)


## What the placement ghost's pill says when the spot won't do.
static func ghost_text(type: String, err: String) -> String:
	if type == "dwelling" and err.begins_with("Must be within"):
		return "Too far from the Hearth · dwellings go inside the ring"
	return err


## The ghost of the building being placed: its sprite over a green or alert tint, and a pill
## saying why when the spot won't do.
static func placement_ghost(ci: CanvasItem, s, type: String, p: Vector2i, note: String) -> void:
	var err: String = s.town.placement_error(type, p)
	var r := rect(p)
	ci.draw_rect(r.grow(-2), Color(0.3, 1, 0.4, 0.4) if err == "" else Color(ALERT, 0.45))
	var tex := Art.building_sprite(type)
	if tex != null and Data.BUILDINGS[type]["kind"] not in ["road", "field"]:
		ci.draw_texture_rect(tex, r.grow(-3), false, Color(1, 1, 1, 0.6))
	ci.draw_rect(r.grow(-2), OUTLINE if err == "" else ALERT, false, 2.0)
	if err != "":
		Art.pill(ci, Vector2(r.get_center().x, r.end.y + 4), ghost_text(type, err), ALERT, Ui.TEXT, 14)
	elif note != "":
		Art.pill(ci, Vector2(r.get_center().x, r.end.y + 4), note, Ui.TEXT, OUTLINE, 14)


## "Road: 7 tiles · 14 Wood · release to lay" for a drag over `tiles`, counting only those it can go on.
static func line_text(s, type: String, tiles: Array) -> String:
	var total := {}
	var n := 0
	for p in tiles:
		if s.town.placement_error(type, p) != "":
			continue
		n += 1
		var cost := Rules.cost_at(type, s.world.tile_at(p))
		for id in cost:
			total[id] = total.get(id, 0) + cost[id]
	var name: String = Data.BUILDINGS[type]["name"]
	if n == 0:
		return "%s: nowhere to lay here" % name
	var text := (
		"%s: %d tile%s · %s" % [name, n, "" if n == 1 else "s", Ui.cost_text(total) if not total.is_empty() else "free"]
	)
	if not s.economy.can_afford(total):
		return text + " · you have enough for part of it"
	return text + " · release to lay"


## Dragging a road, bridge or fields: a white ghost over each tile it can go on, alert on the rest,
## a dashed cursor tile at the end and a pill with the count and cost.
static func line_ghost(ci: CanvasItem, s, type: String, tiles: Array) -> void:
	for p in tiles:
		var r := rect(p)
		if s.town.placement_error(type, p) == "":
			ci.draw_rect(r.grow(-3), Color(OUTLINE, 0.35))
			ci.draw_rect(r.grow(-7), Color(1, 1, 1, 0.55))
		else:
			ci.draw_rect(r.grow(-3), Color(ALERT, 0.45))
	var end: Vector2i = tiles[tiles.size() - 1]
	Art.dashed_rect(ci, rect(end).grow(-1), Color.WHITE, 2.0, 5.0, 4.0)
	Art.pill(
		ci, Vector2(rect(end).get_center().x, rect(end).end.y + 4), line_text(s, type, tiles), Ui.TEXT, OUTLINE, 14
	)


## Hovering a tile nothing can be built on yet says how to get past it.
static func blocked_hint(s, p: Vector2i) -> String:
	match s.world.tile_at(p):
		"river":
			if s.world.roads.has(p):
				return ""
			return "Cross with a Wooden Bridge (Paths & Haulers)"
		"rock":
			return "Cut a pass with a Road (%d Stone)" % Data.PASS_COST["stone"]
	return ""
