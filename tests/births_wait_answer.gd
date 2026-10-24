extends RefCounted
## What the pacing bots do about "Births wait: N Kith have no work. Build workshops to use them." (the line the game shows when a
## fifth of the town has no job). The game teaches that line, and what the first eras taught the player is what the bots use.
## It pauses nothing for surplus (a building at its cap rests by itself and keeps its Kith) that would make births wait, and keeps
## at most SAVING_PAUSES input-saving pauses once they would. After ANSWER_AFTER seconds of waiting it lets go the paused
## buildings the goals are short of and, with no open job left for an idle Kith, builds the next workplace the goals need, one
## every BUILD_GAP seconds.

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

const ANSWER_AFTER := 30.0
const BUILD_GAP := 20.0
const SAVING_PAUSES := 2

var since := -1.0  # the bot's clock when births began to wait for work, -1 while they do not
var built_at := -1000.0  # the clock of the last workplace built to answer the wait


## True while births wait for work.
func waiting(bot) -> bool:
	return bot.s.people.births_wait()


## True when `idle` Kith with no work would still let births go: the bot pauses for surplus only while that holds, so a pause never
## starts the wait (and a wait is not undone one decision and redone the next).
func room(bot, idle: int) -> bool:
	return idle * Data.BIRTHS_WAIT_ONE_IN < bot.s.people.kith.size()


## Called once a decision, before the pauses. `bot` is the pacing bot (tests/autoplay.gd).
func watch(bot) -> void:
	if not waiting(bot):
		since = -1.0
	elif since < 0.0:
		since = bot.clock


## Births have waited a while: let go the paused buildings whose goods the goals are short of, then build a workplace for the
## Kith who have no work (true when one went up). Nothing is built while a job stands open for them.
func answer(bot, short: Dictionary) -> bool:
	var s = bot.s
	if since < 0.0 or bot.clock - since < ANSWER_AFTER:
		return false
	var resumed := false
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		if not b["paused"]:
			continue
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var goods: Array = def["out"].keys() if def["kind"] == "processor" else [b["focus"]]
		for id in goods:
			if short.has(id):
				s.set_paused(i, false)
				resumed = true
				break
	if resumed or bot.clock - built_at < BUILD_GAP or Ui.job_slots(s) > Ui.jobs_filled(s):
		return false
	if bot._next_workplace(short):
		built_at = bot.clock
		return true
	return false


## The next workplace the goals need: the producer of a good some working building lacks, then a workshop for a made good
## still short, then a hut on a raw good still short.
func next_workplace(bot, short: Dictionary) -> bool:
	var s = bot.s
	for b in s.town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if b["paused"] or def["kind"] != "processor":
			continue
		for id in def["in"]:
			if s.economy.inv.get(id, 0) <= 0 and _place_producer(bot, id):
				return true
	for made in bot.MADE_ORDER:
		var type: String = bot.MAKER[made]
		if (
			short.has(made)
			and s.town.unlocked(type)
			and bot._count(type) < bot.WORKSHOPS_MAX
			and bot._place_workshop(type)
		):
			return true
	for id in bot.RAW_TILE:
		if short.has(id) and s.town.unlocked("gatherers_hut") and bot._place_hut(id, bot._huts_for(id)):
			return true
	return false


## A building that makes `id`: its workshop, or a hut gathering it.
func _place_producer(bot, id: String) -> bool:
	var s = bot.s
	if bot.MAKER.has(id):
		var type: String = bot.MAKER[id]
		return s.town.unlocked(type) and bot._count(type) < bot.WORKSHOPS_MAX and bot._place_workshop(type)
	return bot.RAW_TILE.has(id) and s.town.unlocked("gatherers_hut") and bot._place_hut(id, bot._huts_for(id))
