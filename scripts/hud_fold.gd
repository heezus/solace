extends RefCounted
## The side panel folds away so the map is most of the screen. Folded, a two-line goal chip floats at the map's top right
## (it says the current goal, wrapped at a word, and opens the panel); the panel opens by itself while a building's card is up,
## and goes back to the player's choice when the card closes. The choice (key G, the chip, the panel's Fold button) is kept between runs.

const Ui = preload("res://scripts/ui.gd")

const FILE := "user://hud.cfg"
const CHIP_W := 440.0
const CHIP_H := 50.0  # two lines of text: a long goal wraps at a word, it is never cut off
const MARGIN := 10.0
const TEXT_PAD := 24.0  # the button's padding either side of its text

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
	chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var at := line.find(". ")  # the chip keeps the headline; the panel has the rest
	if at > 0:
		line = line.substr(0, at)
	var note := line.find(" (")
	if note > 0 and note + 2 < line.length() and not line[note + 2].is_valid_int():  # a progress count like (2/5) stays
		line = line.substr(0, note)
	if not _fits("Goal: " + line):  # still longer than two lines: keep what comes before the colon (the panel has the rest)
		var colon := line.find(": ")
		if colon > 0:
			line = line.substr(0, colon)
	chip.text = "Goal: " + line


## True when `text` wraps to no more than two lines on the chip.
func _fits(text: String) -> bool:
	var font := chip.get_theme_font("font")
	var size := chip.get_theme_font_size("font_size")
	var wide := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, CHIP_W - TEXT_PAD, size)
	return wide.y <= font.get_height(size) * 2.0 + 1.0
