extends SceneTree
const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
var failures := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)


func fresh() -> Sim:
	var s := Sim.new()
	s.generate(42)
	s.fog.reveal_all()
	return s


func give(s, amount: int) -> void:
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 0 if id in ["bronze_tools", "iron_tools", "steel_tools"] else amount


func _init() -> void:
	var name := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("test="):
			name = a.substr(5)
	var script: GDScript = load("res://tests/%s.gd" % name)
	script.new().run(self)
	print("FAILED: %d" % failures if failures > 0 else "%s PASSED" % name)
	quit(failures)
