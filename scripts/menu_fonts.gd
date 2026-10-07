extends RefCounted
## The faces of the menus (title screen, pause menu, Load and slot screens). One place names them, so the family can be swapped
## by changing the two paths: the display face for the name and every button, a quieter one for small captions. Both are free
## under the SIL Open Font License (fonts/cinzel/OFL.txt). A face that is missing falls back to the theme's default.

const DISPLAY_PATH := "res://fonts/cinzel/CinzelDecorative-Bold.ttf"
const CAPTION_PATH := "res://fonts/cinzel/Cinzel-Variable.ttf"
const CAPTION_WEIGHT := 600  # the variable face's weight axis: semibold reads well small, over a picture

static var _display: Font
static var _caption: Font


## The display face, or null when it is not there.
static func display() -> Font:
	if _display == null and ResourceLoader.exists(DISPLAY_PATH):
		_display = load(DISPLAY_PATH)
	return _display


## The caption face (semibold), or null when it is not there.
static func caption() -> Font:
	if _caption == null and ResourceLoader.exists(CAPTION_PATH):
		var v := FontVariation.new()
		v.base_font = load(CAPTION_PATH)
		v.variation_opentype = {"wght": CAPTION_WEIGHT}
		_caption = v
	return _caption


## `b` in the display face at `size`.
static func style_button(b: Button, size: int) -> void:
	b.add_theme_font_override("font", display())
	b.add_theme_font_size_override("font_size", size)


## `l` in the display face at `size` (the name and the headings).
static func style_display(l: Label, size: int) -> void:
	l.add_theme_font_override("font", display())
	l.add_theme_font_size_override("font_size", size)


## `l` in the caption face (small lines of explanation).
static func style_caption(l: Label) -> void:
	l.add_theme_font_override("font", caption())
