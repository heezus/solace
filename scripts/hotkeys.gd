extends RefCounted
## The keys that open things and move the map (the rest of the keys are in Main._input). One list, so the build bar can print
## each key on its button and the pause menu can show them all. Main passes every key it does not know here.

const Data = preload("res://scripts/data.gd")

## Build bar tab -> key. The tabs the player has not earned yet ignore their key.
const TAB_KEYS := {
	"Homes": KEY_H,
	"Gathering": KEY_A,
	"Workshops": KEY_W,
	"Metal": KEY_M,
	"Logistics": KEY_L,
	"Lore": KEY_E,
	"Craft": KEY_C,
}

## Shown in the pause menu: [key, what it does].
const LIST := [
	["Space or P", "Pause or resume"],
	["1 2 3", "Game speed"],
	["B", "Open or close the build drawer"],
	["H A W M L E C", "Open a build tab: Homes, Gathering, Workshops, Metal, Logistics, Lore, Craft"],
	["T", "Tech tree"],
	["X", "Demolish tool"],
	["G", "Fold or unfold the side panel"],
	["Tab or R", "Next gatherer hut"],
	["Home", "Back to the Hearth"],
	["+ and -", "Zoom"],
	["Esc", "Cancel what you are doing, else the menu"],
]


## The label of a key, as a letter.
static func key_name(tab_name: String) -> String:
	return OS.get_keycode_string(TAB_KEYS[tab_name]) if TAB_KEYS.has(tab_name) else ""


## Handle a key Main does not use itself. True when it did something.
static func press(main: Node, key: int) -> bool:
	if main._modal_up():
		return false
	for tab_name in TAB_KEYS:
		if TAB_KEYS[tab_name] == key:
			main.bottom_bar.press_tab(tab_name)
			return true
	match key:
		KEY_HOME:
			main.center_on(main.state.world.camp_pos)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			main._zoom(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			main._zoom(-1)
		_:
			return false
	return true
