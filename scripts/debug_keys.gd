extends RefCounted
## The debug keys, for testing: F1 adds a stack of every good the era knows, F2 researches every tech that is ready (paying for
## it, topping up whatever is short), F3 cycles the game speed 1x, 3x, 10x, 30x, F4 lifts the fog. They are off unless the
## player switches "Debug keys" on in the pause menu, and then do nothing else; the choice is kept in a small file under user://
## and starts off. Static; `press` is the one entry the game scene calls, the rest work on a Sim and are tested alone.

const Data = preload("res://scripts/data.gd")
const Rules = preload("res://scripts/rules.gd")

const GOODS_STACK := 100
const SPEEDS := [1, 3, 10, 30]

static var path := "user://debug_keys.cfg"
static var _on = null  # null until the file has been read


## True when the keys are switched on.
static func on() -> bool:
	if _on == null:
		var cfg := ConfigFile.new()
		_on = cfg.load(path) == OK and bool(cfg.get_value("debug", "keys", false))
	return _on


## Switch the keys on or off and keep the choice.
static func set_on(value: bool) -> void:
	_on = value
	var cfg := ConfigFile.new()
	cfg.set_value("debug", "keys", value)
	cfg.save(path)


## Forget what was read, so the next `on()` reads the file again.
static func reset() -> void:
	_on = null


## A key was pressed in `game` (scripts/main.gd): do what it is for, and say so in a toast. Nothing happens with the keys off.
static func press(game, key: Key) -> void:
	if not on():
		return
	var said := ""
	match key:
		KEY_F1:
			said = add_goods(game.state)
		KEY_F2:
			said = research_ready(game.state)
		KEY_F3:
			if game.era_card.visible or game.moment_card.visible or game.game_menu.is_open():
				return
			game.speed = next_speed(game.speed)
			game.paused = false
			said = Data.DEBUG_SPEED % game.speed
		KEY_F4:
			game.state.fog.reveal_all()
			said = Data.DEBUG_FOG
		_:
			return
	game._refresh_ui()
	game._toast(said, 2.5)


## The speed after `current` in SPEEDS, round to the first.
static func next_speed(current: int) -> int:
	for v in SPEEDS:
		if v > current:
			return v
	return SPEEDS[0]


## A stack of every good the run's era knows (era 2's once Bronze Dawn is won), not the Bronze Tools, which speed workers up.
static func add_goods(s) -> String:
	var era := 2 if s.won else 1
	for id in Data.ITEM_ORDER:
		if id != "bronze_tools" and int(Data.ITEMS[id].get("era", 1)) <= era:
			s.economy.add(id, GOODS_STACK)
	return Data.DEBUG_GOODS % GOODS_STACK


## Research every tech whose requirements are met, in tree order, topping up what each costs. A tech that opens only once
## another is done waits for the next press. Says what was learned.
static func research_ready(s) -> String:
	var done := []
	for tech in Data.TECH_ORDER:
		if s.tech_tree.researched.has(tech) or not Rules.tech_enabled(tech) or not s.tech_tree.requirements_met(tech):
			continue
		var cost: Dictionary = s.tech_tree.cost_of(tech)
		for id in cost:
			var short: int = cost[id] - s.economy.inv.get(id, 0)
			if short > 0:
				s.economy.add(id, short)
		if s.research(tech):
			done.append(Data.TECHS[tech]["name"])
	return Data.DEBUG_RESEARCH % ", ".join(done) if not done.is_empty() else Data.DEBUG_NO_TECH
