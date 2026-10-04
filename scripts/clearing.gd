extends RefCounted
## Clearing natural land: the Demolish tool on a resource tile (Forest, Rocks, Flax, Berries, Grain, Gravel, Clay) turns
## it into open grass, so a hut can be steered to one resource or a site opened up. It is free and gives nothing back.
## Static: `s` is the Sim. Which tiles may go, and the words, are in scripts/data/tiles.gd (`clearable`, `stays`).
## Not cleared: anything built (that is torn down as before), unexplored land, the river, the Strange Stone, ore, and the
## last tile of a kind (a kind must keep Data.CLEAR_KEEP other tiles on the map, so nothing the settlement needs is
## ever lost for good). A Road or Bridge laid over Rocks or Forest still clears it (Buildings.place).

const Data = preload("res://scripts/data.gd")


## What a Demolish click on the unbuilt tile p would do: {"ok": true when it would clear, "text": the pill's words}.
## `text` is "" where there is nothing to say (open grass, off the map, or something built: see Overlays.demolish_text).
static func check(s, p: Vector2i) -> Dictionary:
	if not s.world.in_bounds(p) or s.town.built_type(p) != "":
		return {"ok": false, "text": ""}
	if not s.fog.is_revealed(p):
		return {"ok": false, "text": Data.CLEAR_FOG}
	var kind: String = s.world.tile_at(p)
	var def: Dictionary = Data.TILES[kind]
	if not def.get("clearable", false):
		return {"ok": false, "text": def.get("stays", "")}
	if _others(s.world, kind, p) < Data.CLEAR_KEEP:
		return {"ok": false, "text": Data.CLEAR_LAST % def["name"]}
	return {"ok": true, "text": Data.CLEAR_TEXT % def["name"]}


## Clear tile p if check allows it: it becomes grass, the walking cell is re-read and every hut re-reads what is in
## its reach. Returns the tile that was there, or "" when nothing was cleared.
static func clear(s, p: Vector2i) -> String:
	if not check(s, p)["ok"]:
		return ""
	var kind: String = s.world.tile_at(p)
	s.world.set_tile(p, "grass")
	s.pathing.update_cell(p)
	if s.harvest_tile == p:
		s.release_harvest()
	refresh_huts(s)
	s.events.append(Data.CLEAR_EVENT % Data.TILES[kind]["name"])
	return kind


## Every Gatherer's Hut re-reads its reach: what it can gather is remembered again, and one whose focus is no longer in
## reach moves to what is nearest it (default_focus), or to none when nothing is left.
static func refresh_huts(s) -> void:
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		if Data.BUILDINGS[b["type"]]["kind"] != "gatherer":
			continue
		b["gather_items"] = []
		for t in s.town.gather_tiles(b["pos"]):
			b["gather_items"].append(Data.TILES[s.world.tile_at(t)]["yields"])
		if b["focus"] == "" or b["focus"] in s.town.focus_options(b["pos"]):
			continue
		var next: String = s.town.default_focus(b["pos"])
		if next == "" or not s.town.set_focus(i, next):
			b["focus"] = ""
			b["gather_index"] = 0


## How many tiles of `kind` there are on the map besides p (sown fields are not wild grain), counted only as far as
## Data.CLEAR_KEEP needs.
static func _others(world, kind: String, p: Vector2i) -> int:
	var n := 0
	for y in world.height:
		for x in world.width:
			var q := Vector2i(x, y)
			if world.tiles[y * world.width + x] == kind and q != p and not world.fields.has(q):
				n += 1
				if n >= Data.CLEAR_KEEP:
					return n
	return n
