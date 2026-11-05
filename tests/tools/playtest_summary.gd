extends SceneTree
## Turn one playtest log (scripts/playtest_log.gd) into the fun rubric's M1 to M15 table with targets and PASS / MISS / N/A.
## Run: godot --headless --path . -s tests/tools/playtest_summary.gd -- <log.jsonl> [--base=<the run 1 log>] [--title="Bug-Hunt, run 1"]
## With no path it reads every log in user://playtest_logs/. Each log's table is printed as markdown.

const PlaytestLog = preload("res://scripts/playtest_log.gd")
const PlaytestSummary = preload("res://scripts/playtest_summary.gd")


func _init() -> void:
	var paths: Array = []
	var base := ""
	var title := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--base="):
			base = a.get_slice("=", 1)
		elif a.begins_with("--title="):
			title = a.get_slice("=", 1)
		else:
			paths.append(a)
	if paths.is_empty():
		for f in DirAccess.get_files_at(PlaytestLog.DIR):
			if f.ends_with(".jsonl"):
				paths.append(PlaytestLog.DIR + f)
	paths.sort()
	for p in paths:
		var entries := PlaytestSummary.read(p)
		var earlier := PlaytestSummary.read(base) if base != "" else []
		print(PlaytestSummary.markdown(PlaytestSummary.rows(entries, earlier), title if title != "" else p.get_file()))
	quit()
