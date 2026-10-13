extends SceneTree
## What Ironfall's ending really leaves. For each map in the args the Ironfall bot plays from the era start to the Livewire gate,
## then this prints the town it earned (Kith, food, stores, techs) next to the scripted `livewire` start's, and plays the earned
## town on through Livewire for 15 minutes with nobody at the controls (the Bloom's tide, food, losses), one line a minute.
## Run: godot --headless --path . -s tests/tools/gate_state.gd -- 1 2

const AutoplayIronfall = preload("res://tests/autoplay_ironfall.gd")
const DevStarts = preload("res://scripts/dev_starts.gd")


func _init() -> void:
	var maps: Array = []
	for a in OS.get_cmdline_user_args():
		maps.append(int(a))
	if maps.is_empty():
		maps = [1]
	var scripted = DevStarts.build("livewire")
	print("SCRIPTED livewire start: ", _summary(scripted))
	for m in maps:
		var bot := AutoplayIronfall.new()
		var game := DevStarts.ironfall_on_map(m, "ironfall", "")
		var r: Dictionary = bot.play_from(game, 90.0 * 60.0)
		print("MAP %d: %s at %.1f min of Ironfall" % [m, "gate reached" if r["won"] else "NO GATE", r["seconds"] / 60.0])
		var marks: Array = []
		for key in r["marks"]:
			marks.append("%s %.1f" % [key, r["marks"][key] / 60.0])
		print("   marks (min): ", ", ".join(marks))
		var s = bot.s
		print("   EARNED at the gate: ", _summary(s))
		for minute in range(1, 16):
			DevStarts._wait(s, 60.0)
			print("   +%2d min: %s  tide begun=%s time=%.0f grown=%d lost=%d" % [minute, _short(s), str(s.tide.begun), s.tide.time, s.tide.grown.size(), s.tide.lost])
	quit(0)


func _short(s) -> String:
	return "kith %d food %.0f (%+.1f/s) steady=%s" % [s.people.kith.size(), s.economy.food_total(), s.economy.food_income(), str(s.economy.food_is_steady())]


func _summary(s) -> String:
	var inv := []
	for id in s.economy.inv:
		if s.economy.inv[id] > 0:
			inv.append("%s %d" % [id, s.economy.inv[id]])
	var counts := {}
	for b in s.town.buildings:
		counts[b["type"]] = counts.get(b["type"], 0) + 1
	return "%s | techs %d | HAVE %s | BUILDINGS %s" % [_short(s), s.tech_tree.researched.size(), ", ".join(inv), str(counts)]
