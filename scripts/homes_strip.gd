extends HBoxContainer
## The Homes tab's own strip, beside the Dwelling card: for each higher tier a small control for the most homes the player
## allows to reach it (the cap that keeps a settlement small on purpose). The cap counts that tier and everything above it, so
## "Homestead or better  2 / 5" means two homes have reached it and the settlement will not grow a sixth. Static buttons, a
## label that is read again each refresh; the rules are in scripts/homes.gd and Buildings.home_cap.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const Homes = preload("res://scripts/homes.gd")

var state: Sim
var values := {}  # tier -> the Label with the count and the cap
var minus := {}  # tier -> its "-" button
var plus := {}  # tier -> its "+" button


func setup(game: Sim) -> void:
	state = game
	add_theme_constant_override("separation", 18)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for tier in range(1, Data.HOME_TIERS.size()):
		add_child(_cap_box(tier))
	refresh()


func _cap_box(tier: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.tooltip_text = Data.HOME_CAP_TIP % Data.HOME_NAMES[tier]
	box.add_child(Ui.heading(Data.HOME_CAP_ROW % Data.HOME_NAMES[tier]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	minus[tier] = _step_button("-", tier, -1)
	row.add_child(minus[tier])
	values[tier] = Ui.label("", Ui.LABEL_TEXT)
	values[tier].custom_minimum_size = Vector2(86, 0)
	values[tier].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(values[tier])
	plus[tier] = _step_button("+", tier, 1)
	row.add_child(plus[tier])
	return box


func _step_button(text: String, tier: int, step: int) -> Button:
	var b := Ui.button(text)
	b.custom_minimum_size = Vector2(32, 28)
	b.pressed.connect(_step.bind(tier, step))
	return b


## Move the cap on `tier` by one. From "no limit" a step down settles on what has already reached it, so the first click
## stops further growth and does not undo any.
func _step(tier: int, step: int) -> void:
	var cap: int = state.town.home_cap(tier)
	if cap >= Data.HOME_CAP_OPEN and step < 0:
		cap = Homes.reaching(state, tier)
	else:
		cap += step
	state.town.set_home_cap(tier, cap)
	refresh()


func refresh() -> void:
	for tier in values:
		var cap: int = state.town.home_cap(tier)
		values[tier].text = (
			Data.HOME_CAP_VALUE
			% [Homes.reaching(state, tier), Data.HOME_CAP_NONE if cap >= Data.HOME_CAP_OPEN else str(cap)]
		)
		minus[tier].disabled = cap <= 0
		plus[tier].disabled = cap >= Data.HOME_CAP_OPEN
