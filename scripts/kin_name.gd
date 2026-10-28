extends RefCounted
## What the player's people are called on screen. They are "Kith" until the first ship's marks (glyph set 7) are read, and "Kin" from then
## on, in every run after (the profile's `kin_known`). Code ids, save keys and the Data strings stay "Kith": the name is changed where
## text is shown, by this one function.
##   say(text): `text` as the player now reads it.
##   Every Label, Button, RichTextLabel and tooltip goes through it by itself: a Translation that is added to the TranslationServer
##   (`Hook`) rewrites the text when the control shapes it, so no string is edited by hand. Text that is drawn with draw_string is the
##   exception: it calls say().
##   set_known(true) is the switch: it changes `known` and has every control on screen shape its text again. The game scene and the
##   title screen set it from the profile (Profile.kin_known_at) as they are built; the notice card sets it when set 7 is read.
## KEPT are the lines that name both words and stay as written: the Hearthkeeper's reveal and the Chronicle's line about it.

const OLD := "Kith"
const NEW := "Kin"
const KEPT := ["We were never only Kith. We are Kin.", "The Kith learned they were Kin"]
const CARD_TITLE := "A new name"
const CARD_TEXT := "Your people are now called Kin."
const CARD_BUTTON := "Go on"

static var known := false  # the people are Kin on screen
static var _hook: Translation = null  # installed, with its Holder in the tree


## `text` with "Kith" read as "Kin" once the people are Kin. The KEPT lines are left alone.
static func say(text: String) -> String:
	if not known or not text.contains(OLD):
		return text
	for i in KEPT.size():
		text = text.replace(KEPT[i], "\u0001%d\u0001" % i)
	text = text.replace(OLD, NEW)
	for i in KEPT.size():
		text = text.replace("\u0001%d\u0001" % i, KEPT[i])
	return text


## Put the Translation in the TranslationServer (once, and only with a running scene tree). Nothing reads differently until `known`.
static func install() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if _hook != null or tree == null:
		return
	var hook := Hook.new()
	hook.filter = say
	hook.locale = "en"
	TranslationServer.add_translation(hook)
	_hook = hook
	var holder := Holder.new()
	holder.hook = hook
	tree.root.add_child(holder)


## Change the name on screen, and have every control shape its text again. Does nothing when it is already so.
static func set_known(on: bool) -> void:
	install()
	if on == known:
		return
	known = on
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)


## The Translation: it hands every text a control shapes to `filter` (say) and keeps the answer when it differs.
class Hook:
	extends Translation
	var filter: Callable

	func _get_message(src_message: StringName, _context: StringName) -> StringName:
		var said: String = filter.call(String(src_message))
		return StringName(said) if said != String(src_message) else &""


## Takes the Translation out again as the game closes: a script's Translation left in the TranslationServer aborts the exit.
class Holder:
	extends Node
	var hook: Translation

	func _exit_tree() -> void:
		TranslationServer.remove_translation(hook)
