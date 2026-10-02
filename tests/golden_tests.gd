extends RefCounted
## Golden regression (design-system/15-architecture.md): the pacing bot plays fixed map seeds, and its
## win time and a hash of the final game state must match tests/golden.json exactly. Every refactor step
## is behavior-preserving, so it must reproduce these numbers. A deliberate gameplay change updates the
## file on purpose: the failure message prints the new values to paste in.
##
## The run is deterministic: the map comes from a seeded RandomNumberGenerator, and the bot drives the
## simulation with a fixed DT (0.1 s), so no wall-clock time and no global random number is involved.
## Run from tests/run_tests.gd, which owns check().

const Sim = preload("res://scripts/sim.gd")
const Data = preload("res://scripts/data.gd")

const GOLDEN_PATH := "res://tests/golden.json"
const BRONZE_PATH := "res://tests/golden_bronze.json"

var t  # the runner, tests/run_tests.gd
var golden: Dictionary = {}  # map seed (as a String) -> {"win_seconds": int, "state_hash": String}
var bronze: Dictionary = {}  # map seed -> {"bronze_seconds": int, "state_hash": String}: the game when the first Bronze is made


## Load the golden values. False (and a failed check) when the file is missing or unreadable.
func load_golden(runner) -> bool:
	t = runner
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		t.check(false, "%s is missing or is not a JSON object" % GOLDEN_PATH)
		return false
	golden = parsed
	var more = JSON.parse_string(FileAccess.get_file_as_string(BRONZE_PATH))
	if typeof(more) != TYPE_DICTIONARY:
		t.check(false, "%s is missing or is not a JSON object" % BRONZE_PATH)
		return false
	bronze = more
	return true


## Compare one bot run (after Autoplay.play) with the golden values for its map seed.
func check_run(map_seed: int, bot) -> void:
	var got := snapshot(bot)
	var want: Dictionary = golden.get(str(map_seed), {})
	var same: bool = (
		not want.is_empty()
		and want.get("win_seconds") == got["win_seconds"]
		and want.get("state_hash") == got["state_hash"]
	)
	if same:
		print("Golden, map %d: %d s, %s" % [map_seed, got["win_seconds"], String(got["state_hash"]).left(12)])
		return
	(
		t
		. check(
			false,
			(
				"golden snapshot differs on map %d\n  want %s\n  got  %s\n  If this change is deliberate, replace the entry for map %d in %s with:\n%s"
				% [map_seed, JSON.stringify(want), JSON.stringify(got), map_seed, GOLDEN_PATH, _entry(map_seed, got)]
			)
		)
	)


## Compare the game at the moment Bronze Dawn is won (the era-2 bot calls this) with tests/golden.json.
func check_dawn(bot, map_seed: int) -> void:
	check_run(map_seed, bot)


## Compare the era-2 bot (tests/autoplay_bronze.gd) at its first Bronze with the second golden snapshot.
func check_bronze(map_seed: int, bot) -> void:
	var got := {
		"bronze_seconds": roundi(bot.bronze_at) if bot.bronze_at >= 0.0 else -1, "state_hash": state_hash(bot.s)
	}
	var want: Dictionary = bronze.get(str(map_seed), {})
	if (
		not want.is_empty()
		and int(want.get("bronze_seconds", -2)) == got["bronze_seconds"]
		and want.get("state_hash") == got["state_hash"]
	):
		print(
			(
				"Golden (first Bronze), map %d: %d s, %s"
				% [map_seed, got["bronze_seconds"], String(got["state_hash"]).left(12)]
			)
		)
		return
	(
		t
		. check(
			false,
			(
				'golden snapshot of the first Bronze differs on map %d\n  want %s\n  got  %s\n  If this change is deliberate, replace the entry for map %d in %s with:\n  "%d": %s'
				% [
					map_seed,
					JSON.stringify(want),
					JSON.stringify(got),
					map_seed,
					BRONZE_PATH,
					map_seed,
					JSON.stringify(got)
				]
			)
		)
	)


func _entry(map_seed: int, got: Dictionary) -> String:
	return '  "%d": {"win_seconds": %d, "state_hash": "%s"}' % [map_seed, got["win_seconds"], got["state_hash"]]


## The bot's result: the win time in whole simulated seconds (-1 when it never won) and the state hash.
func snapshot(bot) -> Dictionary:
	var s: Sim = bot.s
	return {
		"win_seconds": roundi(bot.clock) if s.won else -1,
		"state_hash": state_hash(s),
	}


## A stable hash of the final state: the canonical text below, run through SHA-256. It lists what a
## player would call the game: the stockpile, what's researched, every building with its position, type
## and stock, the roads, fields and fog, and the Kith. Keys are sorted and floats are rounded to
## thousandths, so it doesn't depend on dictionary order or on how a float prints.
func state_hash(s: Sim) -> String:
	return canonical(s).sha256_text()


func canonical(s: Sim) -> String:
	var lines: Array = []
	lines.append("won %s" % s.won)
	lines.append("inv %s" % _counts(_stockpile(s.economy.inv)))
	lines.append("researched %s" % ",".join(_sorted_keys(s.tech_tree.researched)))
	lines.append("ranks %s" % _counts(s.ranks))
	lines.append("goals_done %s" % ",".join(_sorted_keys(s.story.goals_done)))
	lines.append("story %s" % ",".join(s.story.events))
	lines.append("seen %s" % ",".join(_sorted_keys(s.economy.seen)))
	lines.append("hand_counts %s" % _counts(s.hand_counts))
	lines.append("learned %s" % _pairs(s.people.learned_by))
	lines.append("flags %s %s %s %d %d" % [s.hand_tools, s.shard_seen, s.economy.starving, s.rushes, s.people.births])
	lines.append("food_credit %d" % roundi(s.economy.food_credit * 1000.0))
	lines.append("camp %s shard %s" % [_pos(s.world.camp_pos), _pos(s.world.shard_pos)])
	lines.append("tiles %s" % ",".join(s.world.tiles))
	lines.append("fog %d" % s.fog.count())
	lines.append("roads %s" % " ".join(_sorted_positions(s.world.roads)))
	lines.append("fields %s" % " ".join(_sorted_positions(s.world.fields)))
	lines.append("buildings %d" % s.town.buildings.size())
	for b in s.town.buildings:  # in the order they were built: that order decides who works where
		lines.append(
			(
				"b %s %s paused=%s in=%s out=%s"
				% [b["type"], _pos(b["pos"]), b["paused"], _counts(b["inbuf"]), _counts(b["out"])]
			)
		)
	lines.append("kith %d" % s.people.kith.size())
	for k in s.people.kith:
		lines.append("k %s job=%s tool=%d" % [k["name"], k["job"], k["tool"]])
	return "\n".join(lines)


## The stockpile as the stone age knew it: an item of a later era is listed only once there is some of it, so adding
## an era's goods to the game does not change the hash of a game that never touched them.
func _stockpile(inv: Dictionary) -> Dictionary:
	var out := {}
	for id in inv:
		if inv[id] != 0 or int(Data.ITEMS[id].get("era", 1)) == 1:
			out[id] = inv[id]
	return out


func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


func _counts(d: Dictionary) -> String:
	var parts: Array = []
	for id in _sorted_keys(d):
		parts.append("%s=%d" % [id, d[id]])
	return ",".join(parts)


func _pairs(d: Dictionary) -> String:
	var parts: Array = []
	for id in _sorted_keys(d):
		parts.append("%s=%s" % [id, d[id]])
	return ",".join(parts)


func _pos(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]


func _sorted_positions(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return keys.map(_pos)
