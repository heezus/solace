extends RefCounted
## Step 7's painted tellings (docs/art/tellings) as wired: every new picture loads, the ending and next-land stills play in their
## sequences, the elder's portrait sits by the fireside, the relic icons show on the ending card, and the map pieces (ruins, swept
## ground, dormant Bloom, the first ship's hull, the dig) draw without trouble. Run from tests/telling_tests.gd.

const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const Data = preload("res://scripts/data.gd")
const EndingCard = preload("res://scripts/ending_card.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Relics = preload("res://scripts/relics.gd")
const Rendered = preload("res://scripts/rendered_art.gd")
const Ruins = preload("res://scripts/ruins.gd")
const Sim = preload("res://scripts/sim.gd")
const TellingMarks = preload("res://scripts/telling_marks.gd")

const SEED := 5
const MAP_SHEETS := [
	"ruins",
	"ruins_2",
	"ruins_cleared",
	"bloom_dormant",
	"relic_dig",
	"first_wreck",
	"first_wreck_2",
	"relic_everburning_forge",
	"relic_old_lantern",
	"relic_founders_cart",
]
const PORTRAITS := ["portrait_kin_elder", "portrait_sela", "portrait_bloom"]
const NEXT_ART := {"exodus": "next_land_1", "cataclysm": "next_ruins_1", "loop": "next_valley_1"}
const ENDING_ART := {"exodus": "ending_exodus_1", "cataclysm": "ending_cataclysm_1", "loop": "ending_loop_1"}

var t  # the runner, tests/run_tests.gd


## A node that draws the tellings' map pieces and the relic marks in its own _draw, as the map does.
class MapCanvas:
	extends Node2D
	var sim

	func _draw() -> void:
		TellingMarks.draw(self, sim)
		Overlays.relic_marks(self, sim)


func run(runner) -> void:
	t = runner
	test_every_new_picture_loads()
	test_two_paintings_are_told_apart_by_the_tile()
	test_the_next_land_opens_each_run_after_an_ending()
	test_the_fireside_shows_the_ending_then_the_elder()
	test_the_ending_card_shows_the_relic_icons()
	test_the_map_pieces_draw()


func test_every_new_picture_loads() -> void:
	for id in MAP_SHEETS:
		var tex := Rendered.sprite(id, 0)
		t.check(tex != null and tex.get_width() > 0 and tex.get_height() > 0, "%s loads" % id)
	for id in PORTRAITS:
		t.check(ResourceLoader.exists(CutscenePlayer.PORTRAIT_DIR + id + ".png"), "%s is painted" % id)
	for relic in Data.ENDINGS["relics"]:
		t.check(Rendered.relic_icon(relic["id"]) != null, "the %s has an icon" % relic["name"])
	t.check(Rendered.relic_icon("nothing") == null, "and an unknown relic has none")


func test_two_paintings_are_told_apart_by_the_tile() -> void:
	var seen := {}
	for x in 30:
		var p := Vector2i(x, 7)
		var v := Rendered.variant(p, 2, "ruins".hash(), Rendered.map_seed)
		t.check(v == Rendered.variant(p, 2, "ruins".hash(), Rendered.map_seed), "a tile keeps its painting")
		seen[v] = true
	t.check(seen.size() == 2, "and a field of ruins wears both paintings")


func test_the_next_land_opens_each_run_after_an_ending() -> void:
	var first := Sim.new()
	first.generate(SEED)
	var p = CutscenePlayer.new()
	p.setup(first, null, [])
	t.check(p.queue == ["opening"], "a first run opens with its opening only")
	p.free()
	for ending in NEXT_ART:
		var s := Sim.new()
		s.generate(SEED)
		s.carry.from_dict({"exodus": 1, "ending": ending})
		var q = CutscenePlayer.new()
		q.setup(s, null, [])
		t.check(
			q.queue == ["opening", "next_telling"], "after the %s the opening is followed by the next land" % ending
		)
		t.check(q.resolve("next_telling")[0]["art"] == NEXT_ART[ending], "and shows %s" % NEXT_ART[ending])
		t.check(ResourceLoader.exists(Data.CUTSCENE_ART_DIR + NEXT_ART[ending] + ".png"), "painted")
		q.free()


func test_the_fireside_shows_the_ending_then_the_elder() -> void:
	for ending in ENDING_ART:
		var s := Sim.new()
		s.generate(SEED)
		var f = CutscenePlayer.new()
		f.setup(s, null, [])
		s.story.record(Data.ENDINGS[ending]["id"])
		var stills: Array = f.resolve("fireside")
		t.check(stills.size() == 2, "the %s fireside has two stills" % ending)
		t.check(stills[0]["art"] == ENDING_ART[ending], "the first is the %s's own ending" % ending)
		t.check(not stills[0].has("portrait") and stills[1]["art"] == "fireside_1", "then the fireside")
		t.check(stills[1]["portrait"] == "portrait_kin_elder", "with the elder beside the caption")
		t.check(f.texture(stills[1]["portrait"]) != null, "painted")
		f.free()
	var before := Sim.new()
	before.generate(SEED)
	var p = CutscenePlayer.new()
	p.setup(before, null, [])
	t.check(p.variant_key("chosen") == "", "before an ending is told, the Exodus's picture is the default")
	p.free()


func test_the_ending_card_shows_the_relic_icons() -> void:
	var card := EndingCard.new()
	card.setup()
	var icons := []
	_collect(card, icons)
	t.check(icons.size() == Data.ENDINGS["relics"].size(), "three icons under the Cataclysm")
	for icon in icons:
		t.check(icon.texture != null and icon.custom_minimum_size == Vector2(20, 20), "each is the 20 px painting")
	card.free()


func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is TextureRect:
			out.append(c)
		_collect(c, out)


func test_the_map_pieces_draw() -> void:
	var s := Sim.new()
	s.generate(SEED)
	s.fog.reveal(s.world.camp_pos, 200)
	var spots := _open_tiles(s, 6)
	var ruins := []
	for i in 4:
		ruins.append({"pos": [spots[i].x, spots[i].y], "weight": 100 - i * 10})
	s.carry.ending = "cataclysm"
	s.carry.exodus = 1
	s.carry.ruins = ruins
	s.carry.patches = [[spots[4].x, spots[4].y]]
	Ruins.lay(s, Rect2i(0, 0, s.world.width, s.world.height))
	s.starfall.old_ship = spots[5]
	s.starfall.old_ship_found = true
	s.world.set_tile(spots[3], "grass")  # a cleared ruin
	var canvas := MapCanvas.new()
	canvas.sim = s
	t.root.add_child(canvas)
	canvas.notification(CanvasItem.NOTIFICATION_DRAW)  # as the engine would on a redraw
	canvas.free()
	t.check(Relics.waiting(s).size() == 3, "three relics lie under their ruins while the map draws")
	t.check(s.tide.begun == false, "and the patches are still asleep")


## `n` open grass tiles with grass beside them on every side, away from the Hearth.
func _open_tiles(s: Sim, n: int) -> Array:
	var out := []
	for y in range(2, s.world.height - 2):
		for x in range(2, s.world.width - 2):
			var p := Vector2i(x, y)
			var d := (p - s.world.camp_pos).abs()
			if maxi(d.x, d.y) < 10 or maxi(d.x, d.y) > 24 or s.world.tile_at(p + Vector2i(1, 0)) != "grass":
				continue
			if (
				s.world.tile_at(p) == "grass"
				and not out.any(func(q): return (q - p).abs().x < 4 and (q - p).abs().y < 4)
			):
				out.append(p)
				if out.size() == n:
					return out
	return out
