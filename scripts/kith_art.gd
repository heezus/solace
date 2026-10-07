extends RefCounted
## Drawing the Kith on the map: every one of them, all the time. Walking, gathering, hauling, working at a
## building (drawn beside it, not hidden inside) or standing about (spread in a ring, so nobody stacks).
## Rendered walk poses use stable names for appearance and fixed anchors at tile scale.
## The figure is about 0.7 tile tall. A carried item shows above the head.
## Static: `ci` is the map (a CanvasItem drawing in map px, Overlays.TILE a tile), `s` the Sim.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const GrowthArt = preload("res://scripts/growth_art.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Rendered = preload("res://scripts/rendered_art.gd")
const Expedition = preload("res://scripts/expedition.gd")

const KITH := Color("e76f51")
const SPRITE := Overlays.TILE  # the sprite's square: drawn at 1.5x, so its 2-unit outline is 3 px
const RING := 33.0  # how far from its spot an idle Kith stands
const HEARTH_RING := 66.0  # round the Hearth: outside its 2x2 drawing
const SEAT := Vector2(18, 15)  # where a worker stands beside its building, from the tile's center


## Where each Kith is drawn (map units), by index, and whether it is working at its building.
static func spots(s, time: float) -> Array:
	var out: Array = []
	var groups := {}  # tile -> how many stand about there
	for i in s.people.kith.size():
		var k: Dictionary = s.people.kith[i]
		var c: Vector2 = (k["pos"] + Vector2(0.5, 0.5)) * Overlays.TILE
		var spot := {"pos": c, "still": false, "working": false}
		if k["job"] == "work" and k["path"].is_empty() and k["phase"] == "harvest":
			spot["working"] = true  # at the resource tile, hopping while it cuts
		elif k["job"] == "work" and k["path"].is_empty() and k["phase"] != "to_site":
			var b: Dictionary = s.town.buildings[k["building"]]
			spot["pos"] = Overlays.center(b["pos"]) + SEAT
			spot["working"] = true  # beside its building, not hidden inside it
		elif k["path"].is_empty() and k["job"] != "work":
			spot["still"] = true
			var tile := Vector2i(roundi(k["pos"].x), roundi(k["pos"].y))
			spot["tile"] = tile
			spot["n"] = groups.get(tile, 0)
			groups[tile] = groups.get(tile, 0) + 1
		out.append(spot)
	for i in out.size():
		var spot: Dictionary = out[i]
		if spot["still"]:
			var count: int = groups[spot["tile"]]
			var angle: float = TAU * (spot["n"] + 0.5) / count + 0.7
			var sway := Vector2(sin(time * 0.9 + i * 1.7), cos(time * 0.7 + i * 2.3)) * 4.5
			var ring := HEARTH_RING if spot["tile"] == s.world.camp_pos else RING
			spot["pos"] = Overlays.center(spot["tile"]) + Vector2.from_angle(angle) * ring + sway
	return out


static func draw_all(ci: CanvasItem, s, time: float) -> void:
	var spot_list := spots(s, time)
	# Back to front, so a Kith lower on the map is drawn over the one behind it.
	var order := range(spot_list.size())
	order.sort_custom(func(a, b): return spot_list[a]["pos"].y < spot_list[b]["pos"].y)
	for i in order:
		var k: Dictionary = s.people.kith[i]
		var spot: Dictionary = spot_list[i]
		var at: Vector2 = spot["pos"]
		var moving: bool = not k["path"].is_empty()
		if moving:
			at.y += sin(time * 12.0 + at.x) * 2.25
		elif spot["working"]:
			at.y += absf(sin(time * 5.0 + i)) * -3.0  # a little hop while it works
		var flip: bool = moving and k["path"][0].x > k["pos"].x
		var with_cart: bool = k.get("cart", false)
		if with_cart:
			# One Kith and the cart are one picture (Codex's hand cart); what it carries rides in the bed.
			var cargo: Texture2D = null
			for id in k["carry"]:
				cargo = Rendered.named("item_" + id)
				break
			GrowthArt.draw_hand_cart(
				ci, Rect2(at + Vector2(-SPRITE * 0.52, -SPRITE * 0.82), Vector2(SPRITE * 1.04, SPRITE * 1.04)), cargo
			)
			continue
		if Expedition.is_party(k):
			Rendered.party_pack(ci, at, flip)  # behind the body: only the Kith out with a party carry one
		Rendered.kith(ci, at, k.get("name", str(i)), moving, time, flip)
		var above := at + Vector2(-10, -SPRITE * 1.08)  # over the head
		for id in k["carry"]:
			Art.item_icon(ci, id, Rect2(above, Vector2(20, 20)), 1.0)


## The strangers of the era after the Falling Star (Starfall.survivor_spots): three pale-cloaked Lumen figures in a soft light
## so nobody takes them for Kith. They stand about and sway a little; they come closer as they trust the Kith.
static func draw_strangers(ci: CanvasItem, s, time: float) -> void:
	if not s.starfall.arrived():
		return
	var camp := Vector2i(-1, -1)
	for b in s.town.buildings:
		if b["type"] == "lumen_camp":
			camp = b["pos"]
	var spot_list: Array = s.starfall.survivor_spots(s.world.camp_pos, camp)
	for i in spot_list.size():
		var sway := Vector2(sin(time * 0.8 + i * 2.1), cos(time * 0.6 + i * 1.3)) * 3.0
		var at: Vector2 = spot_list[i] * Overlays.TILE + sway
		ci.draw_circle(at - Vector2(0, SPRITE * 0.3), SPRITE * 0.62, Color(0.6, 0.92, 1.0, 0.1))
		ci.draw_circle(at - Vector2(0, SPRITE * 0.3), SPRITE * 0.4, Color(0.6, 0.92, 1.0, 0.14))
		Rendered.stranger(ci, at, i)


## The crash site (Starfall.wreck), once a party has lifted the fog there: a low broken hull in the grass, with embers about it.
static func draw_wreck(ci: CanvasItem, s, time: float) -> void:
	var w: Vector2i = s.starfall.wreck
	if w.x < 0 or not s.starfall.wreck_found or not s.fog.is_revealed(w):
		return
	var c := (Vector2(w) + Vector2(0.5, 0.5)) * Overlays.TILE
	Rendered.wreck(ci, c)
	for i in 3:
		var flick := 0.5 + 0.5 * sin(time * 3.0 + i * 2.0)
		ci.draw_circle(c + Vector2(-22 + i * 22, -6 - 4 * flick), 4.0 + 2.0 * flick, Color(1.0, 0.62, 0.25, 0.55))


## The first Bloom sign (Starfall.bloom), once the Warning is read and the fog is lifted there: a patch of growth nobody
## planted, magenta and sickly green, slowly breathing. Stand-in art until Codex draws it (docs/art/starfall-art-brief.md).
static func draw_bloom_sign(ci: CanvasItem, s, time: float) -> void:
	var b: Vector2i = s.starfall.bloom
	if b.x < 0 or not s.fog.is_revealed(b):
		return
	var c := (Vector2(b) + Vector2(0.5, 0.5)) * Overlays.TILE
	ci.draw_circle(c + Vector2(0, 4), 40.0, Color(0.1, 0.1, 0.1, 0.16))
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var tip := c + Vector2.from_angle(a) * (22.0 + 4.0 * sin(time * 1.4 + i))
		ci.draw_line(c, tip, Color("1b1b1f"), 7.0)
		ci.draw_line(c, tip, Color("6fa84a"), 4.0)
		ci.draw_circle(tip, 5.0, Color("1b1b1f"))
		ci.draw_circle(tip, 3.5, Color("c04a9d"))
	Art.outlined_circle(ci, c, 8.0 + 1.5 * sin(time * 1.4), Color("c04a9d"))


## One Kith standing at `at` (the middle of its feet): its shadow, body and head. A hauler is a shade lighter, and
## one pushing a cart is drawn with it.
static func draw_one(ci: CanvasItem, at: Vector2, hauler: bool, cart := false) -> void:
	var tex := Art.sprite("cart" if cart else ("hauler" if hauler else "kith"))
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(at - Vector2(SPRITE / 2.0, SPRITE * 0.78), Vector2(SPRITE, SPRITE)), false)
		return
	ci.draw_circle(at + Vector2(0, 2), 6.0, Color(0, 0, 0, 0.25))
	Art.outlined_circle(ci, at - Vector2(0, 5), 7.0, KITH.lightened(0.25) if hauler else KITH)
	Art.outlined_circle(ci, at - Vector2(0, 12), 4.5, Color("f4e1c1"))
