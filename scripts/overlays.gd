extends RefCounted
## Map overlays drawn over the tiles and buildings: demolish hover and rubble, flow arrows for the
## selected workshop, status pills pinned under buildings, the settlement ring, and the fog.
## Static: each takes the CanvasItem to draw on (the map) and the Sim.

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const FieldText = preload("res://scripts/field_text.gd")
const Clearing = preload("res://scripts/clearing.gd")

const TILE := 48.0  # map px per tile at the default zoom
const OUTLINE: Color = Art.OUTLINE
const ALERT: Color = Ui.BAD
const KITH: Color = Ui.KITH
const RUBBLE_TIME := 0.9
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CORNERS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


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
		return Clearing.check(s, p)["text"]  # a resource tile: what clearing it loses, or why it stays
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
	var keeps: bool = type == "" and not Clearing.check(s, p)["ok"]  # a tile that stays: grass, fog, river, the last one
	if keeps or (type != "" and Data.BUILDINGS[type]["kind"] == "camp"):
		ci.draw_rect(r.grow(-2), Color(1, 1, 1, 0.5), false, 2.0)
		if demolish_text(s, p) != "":
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
	var used := Buildings.recipe_in(b)
	for id in used:
		var off := Vector2(0, 6 * k)
		flow_arrow(
			ci, depot + off, here + off, Data.ITEMS[id]["color"], "%d %s" % [used[id], Data.ITEMS[id]["name"]], time
		)
		k += 1
	var made := Buildings.recipe_out(b)
	for id in made:
		flow_arrow(ci, here, depot, Data.ITEMS[id]["color"], "%d %s" % [made[id], Data.ITEMS[id]["name"]], time)


## The word on an alert's pill: "Hungry: no food" says "Hungry", "Idle: no free Kith" says "Idle". The whole
## alert is still in the building's status, in its card and on hover.
static func pill_text(alert: String) -> String:
	return alert.split(":")[0]


## Where a blocked building's alert badge sits: its lower right corner, inside its own tile, so it never covers a
## neighbour, another badge or a "click" badge (those float above the tile).
static func alert_badge_at(p: Vector2i) -> Vector2:
	return rect(p).end - Vector2(10.0, 10.0) * Art.ui_k


## Blocked buildings (hungry, no power, no road...) wear a 16 px alert-red badge on their lower right corner. No
## text on the map: the words are in the Info panel while the mouse is over the building. (Playtest 5 had pills
## stacking over each other and over the next building; a badge inside its own tile cannot.)
static func alert_badges(ci: CanvasItem, s) -> void:
	var font := ThemeDB.fallback_font
	for b in s.town.buildings:
		if b["alert"] == "":
			continue
		var at := alert_badge_at(b["pos"])
		var radius := 8.0 * Art.ui_k
		ci.draw_circle(at, radius, ALERT)
		ci.draw_arc(at, radius, 0, TAU, 24, Ui.LINE, maxf(2.0 * Art.ui_k, 1.0), true)
		var px := roundi(14.0 * Art.ui_k)
		var wide := font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(font, at + Vector2(-wide / 2.0, px * 0.36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ui.TEXT)


## The edge of the lit land: each explored tile next to fog fades into the fog color over its own width, so the
## border is one soft tile wide with no ragged rim. Nothing of the fogged land shows through.
static func fog_edges(ci: CanvasItem, s, seen: Rect2i) -> void:
	var fog: Color = Data.FOG
	for y in range(seen.position.y, seen.end.y):
		for x in range(seen.position.x, seen.end.x):
			var p := Vector2i(x, y)
			if not s.fog.is_revealed(p):
				continue
			var r := rect(p)
			for d in SIDES:
				if _fogged(s, p + d):
					_fade_side(ci, r, d, fog)
			for d in CORNERS:
				if _fogged(s, p + d) and not _fogged(s, p + Vector2i(d.x, 0)) and not _fogged(s, p + Vector2i(0, d.y)):
					var corner := r.get_center() + Vector2(d) * TILE * 0.5
					var pts := PackedVector2Array(
						[corner, corner - Vector2(d.x * TILE * 0.6, 0), corner - Vector2(0, d.y * TILE * 0.6)]
					)
					ci.draw_polygon(pts, PackedColorArray([fog, Color(fog, 0.0), Color(fog, 0.0)]))


static func _fogged(s, p: Vector2i) -> bool:
	return s.world.in_bounds(p) and not s.fog.is_revealed(p)


## A strip across tile `r`, clear on the side away from the fog and solid fog color at the edge facing it.
static func _fade_side(ci: CanvasItem, r: Rect2, toward: Vector2i, fog: Color) -> void:
	var edge := r.get_center() + Vector2(toward) * TILE * 0.5
	var across := Vector2(absf(toward.y), absf(toward.x)) * TILE * 0.5
	var back := Vector2(toward) * TILE
	var mid := Color(fog, 0.35)
	var near := PackedVector2Array(
		[edge - across, edge + across, edge + across - back * 0.5, edge - across - back * 0.5]
	)
	ci.draw_polygon(near, PackedColorArray([fog, fog, mid, mid]))
	var far := PackedVector2Array(
		[edge - across - back * 0.5, edge + across - back * 0.5, edge + across - back, edge - across - back]
	)
	ci.draw_polygon(far, PackedColorArray([mid, mid, Color(fog, 0.0), Color(fog, 0.0)]))


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
		var cost: Dictionary = s.town.cost_here(type, p)
		for id in cost:
			total[id] = total.get(id, 0) + cost[id]
	var name: String = Data.BUILDINGS[type]["name"]
	if n == 0:
		return "%s: nowhere to lay here" % name
	var text := (
		"%s: %d tile%s · %s" % [name, n, "" if n == 1 else "s", Ui.cost_text(total) if not total.is_empty() else "free"]
	)
	if Data.BUILDINGS[type]["kind"] == "field":
		text += " · " + FieldText.drag_note(s, type, tiles)
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
			if s.tech_tree.researched.has("causeways"):
				return "Cross with a Stone Bridge (carts need one) or a Wooden Bridge"
			return "Cross with a Wooden Bridge (Paths & Haulers)"
		"rock":
			return "Cut a pass with a Road (%d Stone)" % Data.PASS_COST["stone"]
	return ""
