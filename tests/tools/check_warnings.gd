extends SceneTree
## Editor warnings as errors. With "list" it prints each GDScript warning the editor shows (level Warn);
## tests/tools/check_warnings.sh raises those to errors in an override.cfg, then runs this again to load
## every script in scripts/ and tests/, so a warning the project owner would see in the editor fails CI instead.

const PREFIX := "debug/gdscript/warnings/"
const WARN := 1


func _init() -> void:
	if "list" in OS.get_cmdline_user_args():
		for prop in ProjectSettings.get_property_list():
			var name: String = prop["name"]
			if name.begins_with(PREFIX) and typeof(ProjectSettings.get_setting(name)) == TYPE_INT:
				if ProjectSettings.get_setting(name) == WARN:
					print(name.trim_prefix("debug/"))
		quit(0)
		return
	var bad: Array = []
	var count := 0
	for dir in ["res://scripts", "res://tests"]:
		for path in _scripts(dir):
			count += 1
			if ResourceLoader.load(path) == null:
				bad.append(path)
	print("Loaded %d scripts with editor warnings as errors" % count)
	if not bad.is_empty():
		printerr("Scripts with warnings: %s" % [bad])
	quit(1 if not bad.is_empty() else 0)


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out += _scripts(dir.path_join(d))
	return out
