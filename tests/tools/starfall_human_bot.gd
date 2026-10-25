extends "res://tests/autoplay_starfall.gd"
## The Starfall bot with the oracle taken out: the town plays itself as in the pacing runs, but the guesses on the Glyph Wall come
## from a player who sees only a page (the marks, where each was found, the words left). Game time stands still while the page is
## answered. Run by tests/tools/starfall_human.gd; the page protocol is the one tests/tools/ai_player.gd uses (snapshot_<n>.txt in,
## moves_<n>.json out, here {"guesses": {"Mark 4": "Light"}}).

const RETRY_AFTER := 25.0  # game seconds: a check (every 20) has had its turn since the guesses went in
const MAX_PAGES := 100
const POLL_MS := 500

var dir := "user://starfall_player/"
var patience := 900.0
var timed_out := false
var pages := 0
var sets := {}  # set id -> {"first", "last", "read", "wrong_marks", "wrong_rounds", "rounds"}
var _label := {}  # glyph id -> "Mark <n>" in the order the Wall got them
var _seen_at := {}  # glyph id -> seconds into the era when the mark appeared
var _sent_at := {}  # set id -> seconds into the era the set's guesses last went in (-1 once paged for a retry)
var _tried := {}  # glyph id -> {word -> true} for the wrong words ever set


func _guess() -> void:
	var f: Starfall = s.starfall
	_note(f)
	if pages >= MAX_PAGES or timed_out:
		return
	var why := _why_page(f)
	if why == "":
		return
	pages += 1
	_write(dir + "snapshot_%d.txt" % pages, _page(f, why))
	var moves: Variant = _await(pages)
	if timed_out:
		return
	_apply(f, moves)


## Note when each mark came onto the Wall and when each set was read.
func _note(f: Starfall) -> void:
	var now := clock - _start_at
	for g in f.copied:
		if not _label.has(g):
			_label[g] = "Mark %d" % (_label.size() + 1)
			_seen_at[g] = now
			var rec := _rec(Starfall.set_of(g))
			rec["first"] = minf(rec["first"], now) if rec["first"] >= 0.0 else now
			rec["last"] = now
	for id in f.locked:
		var rec := _rec(id)
		if rec["read"] < 0.0:
			rec["read"] = now


func _rec(set_id: String) -> Dictionary:
	if not sets.has(set_id):
		sets[set_id] = {"first": -1.0, "last": -1.0, "read": -1.0, "wrong_marks": 0, "wrong_rounds": 0, "rounds": 0}
	return sets[set_id]


## "" when no page is due. A page is due when a set has all its marks on the Wall and has not been answered yet, or when it was
## answered, a check has come and gone, and the Kith still have not read it.
func _why_page(f: Starfall) -> String:
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if f.locked.has(gset["id"]) or f.progress(gset["id"]).x < f.progress(gset["id"]).y:
			continue
		if not _sent_at.has(gset["id"]):
			return "new"
		if _sent_at[gset["id"]] >= 0.0 and clock - _start_at - _sent_at[gset["id"]] >= RETRY_AFTER:
			_sent_at[gset["id"]] = -1.0
			if _all_right(f, gset):
				continue  # nothing wrong to mend: the set waits on the game (the Warning waits for the strangers' questions)
			return "retry"
	return ""


func _all_right(f: Starfall, gset: Dictionary) -> bool:
	for g in gset["glyphs"]:
		if f.guesses.get(g, "") != Data.GLYPHS[g]["word"]:
			return false
	return true


func _page(f: Starfall, why: String) -> String:
	var out: Array = []
	out.append("PAGE %d · game time %s · the Lumen are: %s" % [pages, _mmss(clock - _start_at), f.trust_word()])
	out.append("")
	(
		out
		. append(
			"The Glyph Wall holds the marks below. Each mark stands for one word from the list at the end. A set is read when all"
		)
	)
	(
		out
		. append(
			"its marks have the right word at a Kith check; the Kith say nothing otherwise, and tell you nothing about which is wrong."
		)
	)
	if why == "retry":
		out.append("")
		(
			out
			. append(
				"Time has passed since your last answer and at least one complete set below is STILL NOT READ: some guess in it is wrong."
			)
		)
	out.append("")
	for n in f.set_order():
		var gset: Dictionary = Data.GLYPH_SETS[n]
		var have := f.progress(gset["id"])
		if have.x == 0:
			continue
		var head := (
			"Set %d of %d: %d of %d marks copied" % [f.set_number(gset["id"]), Data.GLYPH_SETS.size(), have.x, have.y]
		)
		if f.locked.has(gset["id"]):
			out.append("%s: READ (settled, nothing to do)" % head)
			continue
		out.append(head)
		for g in f.glyph_order(n):
			if not f.copied.has(g):
				continue
			out.append("  %s · set to: %s" % [_label[g], f.guesses.get(g, Data.NO_GUESS)])
			for line in f.found_lines(g):
				out.append("      found: %s" % line)
	out.append("")
	var read: Array = f._read_words()
	out.append(
		(
			"Words already settled by read sets (cannot be used again): %s"
			% (", ".join(read) if not read.is_empty() else "none")
		)
	)
	var open: Array = Data.GLYPH_WORDS.filter(func(w): return w not in read)
	out.append("Word list: %s" % ", ".join(open))
	out.append("")
	(
		out
		. append(
			(
				'Answer with moves_%d.json: {"guesses": {"Mark 1": "Star", ...}}  (any marks you want to set or change; others stay)'
				% pages
			)
		)
	)
	return "\n".join(out)


## Set the guesses the way clicks do (cycle_guess) and count the wrong ones.
func _apply(f: Starfall, moves) -> void:
	var by_label := {}
	for g in _label:
		by_label[_label[g]] = g
	var guesses: Dictionary = moves.get("guesses", {}) if typeof(moves) == TYPE_DICTIONARY else {}
	var touched := {}
	for key in guesses:
		var g: String = by_label.get(String(key), "")
		var word := String(guesses[key])
		if g == "" or word not in Data.GLYPH_WORDS:
			continue
		var set_id := Starfall.set_of(g)
		if f.locked.has(set_id):
			continue
		for i in Data.GLYPH_WORDS.size():
			if f.guesses.get(g, "") == word:
				break
			f.cycle_guess(g)
		if f.guesses.get(g, "") != word:
			continue  # the word is settled elsewhere: the click skipped it
		touched[set_id] = true
		if word != Data.GLYPHS[g]["word"]:
			if not _tried.has(g):
				_tried[g] = {}
			if not _tried[g].has(word):
				_tried[g][word] = true
				_rec(set_id)["wrong_marks"] += 1
	for set_id in touched:
		_sent_at[set_id] = clock - _start_at
		_rec(set_id)["rounds"] += 1
		var wrong := false
		for g in Data.GLYPH_SETS.values().filter(func(x): return x["id"] == set_id)[0]["glyphs"]:
			wrong = wrong or (f.copied.has(g) and f.guesses.get(g, "") != Data.GLYPHS[g]["word"])
		if wrong and f.progress(set_id).x == f.progress(set_id).y:
			_rec(set_id)["wrong_rounds"] += 1
	for gset in Data.GLYPH_SETS.values():
		if not _sent_at.has(gset["id"]) and f.progress(gset["id"]).x == f.progress(gset["id"]).y:
			_sent_at[gset["id"]] = clock - _start_at  # a complete set the answer did not touch: wait out a check, then ask again


func _await(n: int) -> Variant:
	var path := dir + "moves_%d.json" % n
	var waited := 0.0
	while waited < patience:
		if FileAccess.file_exists(path):
			OS.delay_msec(300)
			return JSON.parse_string(FileAccess.get_file_as_string(path))
		OS.delay_msec(POLL_MS)
		waited += POLL_MS / 1000.0
	timed_out = true
	return {}


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _mmss(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]
