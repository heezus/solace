extends RefCounted
## What the headless players do about the Lumen buildings (design-system/16-starfall.md, "Stage 5 as built"): how many of each they
## raise and where, for the Starfall bot, and the echoes the Kith carry into a later run (the Exodus). An echo opens a Lumen card
## from the start, so a bot that knows it (the bots in era N know everything from eras 1 to N-1) builds the Shard Lantern and the
## Healing House as soon as their materials are in the stores, in any era. The Grove and the Shardwright wait for Starfall: their
## goods are that era's work, and the Shardwright would eat the Rope and Bronze the eras between need. All static, over the bot.

const Data = preload("res://scripts/data.gd")
const Bonuses = preload("res://scripts/bonuses.gd")

const LANTERNS_MAX := 3  # Shard Lanterns: the first by the Grove and the Shardwright, the rest by gatherers still in the dark
const GROVES := 1  # Starfruit Groves: one grows the Ward's 60 Starfruit in about 7 minutes
const ECHO_SETS := ["light", "body"]  # the echoes a bot builds before Starfall


## One echo building, true when it was placed (the decision is spent). Nothing for a first run.
static func echoes(bot) -> bool:
	if bot.s.carry.is_first():
		return false
	for id in ECHO_SETS:
		var type: String = Data.LUMEN["cards"][id]["building"]
		if bot.s.carry.has_echo(id) and bot._count(type) < want_of(bot, type) and place(bot, type):
			return true
	return false


## How many of a building the era's bot raises: one of each, but Lanterns follow the dark gatherers and Groves are two.
static func want_of(bot, type: String) -> int:
	match type:
		"shard_lantern":
			return LANTERNS_MAX if bot._count(type) == 0 or huts_in_the_dark(bot) > 0 else 0
		"starfruit_grove":
			return GROVES
	return 1


## Gatherers' Huts no shardlight reaches.
static func huts_in_the_dark(bot) -> int:
	var n := 0
	for b in bot.s.town.buildings:
		if b["type"] == "gatherers_hut" and not Bonuses.lit(bot.s, b["pos"]):
			n += 1
	return n


## Place one Lumen building: a Lantern where it lights the most huts still in the dark (the first one near the Hearth, for the Grove
## and the Shardwright), those two only inside shardlight, the rest near the Hearth.
static func place(bot, type: String) -> bool:
	var s = bot.s
	var hearth := Vector2(s.world.camp_pos)
	match type:
		"shard_lantern":
			return bot._place_best(
				type,
				func(p):
					var dark := 0
					for b in s.town.buildings:
						if (
							b["type"] == "gatherers_hut"
							and Vector2(b["pos"]).distance_to(Vector2(p)) <= Data.SHARDLIGHT_RADIUS
						):
							dark += 0 if Bonuses.lit(s, b["pos"]) else 1
					if bot._count(type) > 0 and dark == 0:
						return -INF
					return dark * 4.0 - Vector2(p).distance_to(hearth)
			)
		"starfruit_grove", "shardwright":
			return bot._place_best(type, func(p): return -Vector2(p).distance_to(hearth) if Bonuses.lit(s, p) else -INF)
	return bot._place_near_hearth(type)
