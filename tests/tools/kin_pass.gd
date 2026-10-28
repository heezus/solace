extends SceneTree
## The Kin on screen, in the running tree (tests/kin_name_tests.gd checks the words and the card without one): every Label, Button,
## RichTextLabel and tooltip shows "Kith" until the first ship is read and "Kin" after, controls built before the change and after
## it, the reveal's own line stays as written, and the card that says so comes up once the Hearthkeeper has finished and takes no
## second look. It fails the run on any wrong step, and the run must close cleanly (the Translation is taken out as the game closes).
## Run: godot --headless --fixed-fps 60 --path . -s tests/tools/kin_pass.gd

const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const KinName = preload("res://scripts/kin_name.gd")
const NoticeCard = preload("res://scripts/notice_card.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")
const Words = preload("res://scripts/chronicle_words.gd")

const PROFILE := "user://kin_pass_profile.json"
const LINE := "A Kith was born. We were never only Kith. We are Kin."

var frame := 0
var problems: Array = []
var label: Label
var button: Button
var rich: RichTextLabel
var card: NoticeCard
var player: Node
var sim: Sim


func _init() -> void:
	Profile.forget(PROFILE)
	label = Label.new()
	button = Button.new()
	rich = RichTextLabel.new()
	root.add_child(label)
	root.add_child(button)
	root.add_child(rich)


## Called once per frame; true ends the run.
func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		KinName.install()
		_expect(KinName.known == false, "the people begin as Kith")
		label.text = LINE
		button.text = "Kith: 3"
		button.tooltip_text = "Where the Kith sleep"
		rich.text = "The Kith's fire"
		_expect(label.get_total_character_count() == LINE.length(), "a Label reads as written before")
		_expect(rich.get_parsed_text() == "The Kith's fire", "and a RichTextLabel")
	if frame == 4:
		sim = Sim.new()
		sim.generate(5)
		card = NoticeCard.new()
		card.profile_path = PROFILE
		root.add_child(card)
		card.setup()
		player = CutscenePlayer.new()
		root.add_child(player)
		player.setup(sim, null, [])
		sim.story.record(Profile.KIN_EVENT)
		_expect(player.pending("kin_reveal"), "set 7 read: the Hearthkeeper's telling is waiting")
		_expect(not card.poll(sim, false) and not KinName.known, "the people are still Kith while it plays")
	if frame == 6:
		player.queue.erase("kin_reveal")  # it has played
		_expect(card.poll(sim, false) and card.visible, "the card is up once the telling is over")
		_expect(KinName.known, "the people are Kin")
	if frame == 8:
		var words := ""
		for c in card.find_children("*", "Label", true, false):
			words += c.text
		_expect(words.contains(KinName.CARD_TEXT), "the card says so")
		_expect(
			label.get_total_character_count() == LINE.length() - 1,
			"a Label built before the change now says Kin: one letter less"
		)
		_expect(rich.get_parsed_text() == "The Kin's fire", "so does a RichTextLabel")
		_expect(
			button.tr(button.text) == "Kin: 3" and button.tr(button.tooltip_text) == "Where the Kin sleep",
			"and a Button with its tooltip"
		)
		var fresh := Label.new()
		root.add_child(fresh)
		fresh.text = LINE
		_expect(fresh.get_total_character_count() == LINE.length() - 1, "a Label built after says Kin too")
		_expect(KinName.say(LINE).contains("We were never only Kith. We are Kin."), "the reveal's line is as written")
		var again := NoticeCard.new()
		again.profile_path = PROFILE
		root.add_child(again)
		again.setup()
		_expect(not again.poll(sim, false), "a later run takes no second card")
	if frame >= 10:
		Profile.forget(PROFILE)
		if problems.is_empty():
			print("KIN PASS OK")
		else:
			for p in problems:
				printerr("KIN PASS FAILED: ", p)
		quit(0 if problems.is_empty() else 1)
		return true
	return false


func _expect(ok: bool, what: String) -> void:
	if not ok:
		problems.append(what)
