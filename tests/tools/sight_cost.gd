extends SceneTree
## What Sight costs on a kept town: the data pass (once a second) and the draw (every frame), headless.
## Run: godot --headless --path . -s tests/tools/sight_cost.gd -- <kept start .json or baseline checkpoint .json>

const RunSave = preload("res://scripts/run_save.gd")
const Sight = preload("res://scripts/sight.gd")
const Sim = preload("res://scripts/sim.gd")

const FRAMES := 60


## A node that times the Sight draw inside its own _draw.
class Probe:
	extends Node2D
	var sight
	var view := Rect2()
	var micros: Array = []

	func _draw() -> void:
		var from := Time.get_ticks_usec()
		sight.draw(self, Vector2(600, 400), 1.0, view)
		micros.append(Time.get_ticks_usec() - from)


func _init() -> void:
	var text := FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0])
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("run"):
		text = parsed["run"]
	var s := Sim.new()
	RunSave.restore(s, RunSave.from_json(text))
	for i in 600:
		s.tick(0.1)  # a minute of hauling fills the trip log
	var sight := Sight.new()
	var gather: Array = []
	for i in 30:
		var from := Time.get_ticks_usec()
		sight.gather(s)
		gather.append(Time.get_ticks_usec() - from)
	print(
		(
			"town: %d buildings, %d gaps, %d flows, %d depots, %d nets"
			% [s.town.buildings.size(), sight.gaps.size(), sight.flows.size(), sight.depots.size(), sight.nets.size()]
		)
	)
	print("data pass: mean %.2f ms, worst %.2f ms (bar: under 2 ms)" % [_mean(gather) / 1000.0, gather.max() / 1000.0])
	var probe := Probe.new()
	probe.sight = sight
	root.add_child(probe)
	var hearth := Vector2(s.world.camp_pos) * 48.0
	var views := {
		"on screen (1600 x 900 px at 48 px a tile)": Rect2(hearth - Vector2(800, 450), Vector2(1600, 900)),
		"whole map in view (worst case)": Rect2(-1.0e5, -1.0e5, 2.0e5, 2.0e5),
	}
	for label in views:
		probe.view = views[label]
		probe.micros = []
		for i in FRAMES:
			probe.queue_redraw()
			await process_frame
		probe.micros.remove_at(0)  # the first frame builds the font cache
		var mean := _mean(probe.micros) / 1000.0
		print("draw, %s: mean %.2f ms, worst %.2f ms (bar: under 4 ms)" % [label, mean, probe.micros.max() / 1000.0])
	quit(0)


func _mean(list: Array) -> float:
	var sum := 0.0
	for v in list:
		sum += v
	return sum / maxf(list.size(), 1)
