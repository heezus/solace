extends SceneTree
## Bake the stage starts the bots make (scripts/dev_starts.gd) into res://stage_starts/, with the fingerprint of the data they
## were built from, so a release export can ship them and the first click on a start is instant. The folder is not in the repo
## (.gitignore); .github/workflows/release.yml runs this before exporting. Takes a few minutes: a bot plays the whole era.
## Fails (exit 1) when a start is missing afterwards.
## Run: godot --headless --path . -s tests/tools/bake_starts.gd

const DevStarts = preload("res://scripts/dev_starts.gd")
const RunSave = preload("res://scripts/run_save.gd")


func _init() -> void:
	DevStarts.cache_dir = DevStarts.BAKED_DIR  # what is written is what the game reads first
	DevStarts.baked_dir = ""
	DevStarts.clear_cache()
	var baked := 0
	var failed := []
	for id in DevStarts.ids():
		var began := Time.get_ticks_msec()
		var s = DevStarts.build(id)
		print("%s: %.1f s" % [id, float(Time.get_ticks_msec() - began) / 1000.0])
		if s == null:
			failed.append(id)
	for f in DirAccess.get_files_at(DevStarts.BAKED_DIR):
		var kept := RunSave.from_json(FileAccess.get_file_as_string(DevStarts.BAKED_DIR + f))
		if kept.get("fingerprint", "") == DevStarts.fingerprint() and RunSave.is_run_save(kept.get("run")):
			baked += 1
			print("baked ", f)
		else:
			failed.append(f)
	if baked < 3:
		failed.append("the bot-made starts (found %d)" % baked)
	if failed.is_empty():
		print("BAKE OK: %d starts" % baked)
		quit(0)
	else:
		printerr("BAKE FAILED: ", failed)
		quit(1)
