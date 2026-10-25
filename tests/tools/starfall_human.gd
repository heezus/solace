extends SceneTree
## Starfall's real length: the town plays itself as in the pacing runs, a player who sees only pages makes the Glyph Wall guesses.
## Run: godot --headless --path . -s tests/tools/starfall_human.gd -- --dir=/some/folder [--seed=1] [--minutes=60] [--patience=900]
## The player reads snapshot_<n>.txt in the folder and writes moves_<n>.json ({"guesses": {"Mark 1": "Star"}}); result.json at the end
## holds the minutes, the milestones and, per set, when its marks came, when it was read and how many wrong guesses it took.

const DevStarts = preload("res://scripts/dev_starts.gd")
const Bot = preload("res://tests/tools/starfall_human_bot.gd")


func _init() -> void:
	var dir := "user://starfall_player/"
	var map_seed := 1
	var minutes := 60.0
	var patience := 900.0
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"dir":
				dir = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"seed":
				map_seed = int(kv[1])
			"minutes":
				minutes = float(kv[1])
			"patience":
				patience = float(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var game := DevStarts.star_on_map(map_seed, "user://pace_starts/")
	var bot := Bot.new()
	bot.dir = dir
	bot.patience = patience
	var r: Dictionary = bot.play_starfall(game, game.seasons.time, minutes * 60.0)
	var out := {
		"seed": map_seed,
		"over": r["won"],
		"minutes": snappedf(r["seconds"] / 60.0, 0.01),
		"timed_out": bot.timed_out,
		"pages": bot.pages,
		"marks": r["marks"],
		"sets": bot.sets,
	}
	var file := FileAccess.open(dir + "result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  "))
	file.close()
	print(
		(
			"Starfall with a player: map %d, %s at %.1f min, %d pages"
			% [map_seed, "over" if r["won"] else "NOT over", r["seconds"] / 60.0, bot.pages]
		)
	)
	quit(0)
