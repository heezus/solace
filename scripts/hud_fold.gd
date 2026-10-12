extends RefCounted
## The side panel folds away so the map is most of the screen. Folded, a one-line goal chip floats at the map's top right
## (it says the current goal and opens the panel); the panel opens by itself while a building's card is up, and goes back to
## the player's choice when the card closes. The choice (key G, the chip, the panel's Fold button) is kept between runs.

const Ui = preload("res://scripts/ui.gd")

const FILE := "user://hud.cfg"
const CHIP_W := 420.0
const CHIP_H := 30.0
const MARGIN := 10.0

var folded := true  # the player's choice; folded is how a first run starts
var chip: Button
var _side: Control


func setup(layer: Node, side_panel: Control) -> void:
	_side = side_panel
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		folded = bool(cfg.get_value("hud", "side_folded", true))
	chip = Ui.button("")
	chip.custom_minimum_size = Vector2(CHIP_W, CHIP_H)
	chip.size = chip.custom_minimum_size
	chip.clip_text = true
	chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	chip.tooltip_text = "Goals and the info panel: click or press G"
	chip.pressed.connect(toggle)
	layer.add_child(chip)


## True when the side panel is showing: the player's choice, or a building's card is open.
func is_open(card_open: bool) -> bool:
	return not folded or card_open


func toggle() -> void:
	set_folded(not folded)


func set_folded(on: bool) -> void:
	folded = on
	var cfg := ConfigFile.new()
	cfg.set_value("hud", "side_folded", folded)
	cfg.save(FILE)  # best effort: a read-only disk just forgets the choice


## Show or hide the panel and the chip, and put the chip at the map's top right.
func place(view: Rect2, card_open: bool) -> void:
	var open := is_open(card_open)
	_side.visible = open
	chip.visible = not open
	chip.position = Vector2(view.end.x - CHIP_W - MARGIN, view.position.y + MARGIN)


## The chip says the current goal (the side panel's first goal line, without its marker).
func refresh(goal_text: String) -> void:
	var line := goal_text.trim_prefix("> ").strip_edges()
	for cut in [" (", ". "]:  # the chip keeps the headline; the panel has the rest
		var at := line.find(cut)
		if at > 0:
			line = line.substr(0, at)
	chip.text = "Goal: " + line
