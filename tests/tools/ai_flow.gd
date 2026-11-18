extends RefCounted
## The AI player's flow-view hand (fun playtest 5: the journalist never saw the flow view or the "at this rate" lines because the table's
## page did not print them). `lines` is the page's FLOW part: what the goal's goods make and use a minute, what holds each one up, and the
## "at this rate" sum of the goal in front of the player. `move` runs the flow view's own buttons: {"do":"flow"} lists every good on the
## next page (the view opened), {"do":"flow","pause_them":true} presses "Pause them" on the rival line. Pure reads of FlowView and
## GoalSums; the pause goes through the game's own `set_paused`.

const Data = preload("res://scripts/data.gd")
const FlowView = preload("res://scripts/flow_view.gd")
const GoalSums = preload("res://scripts/goal_sums.gd")
const Needs = preload("res://scripts/needs.gd")

const MOVES := ["flow"]
static var _all_open := false  # the next page lists every good, not just the goal's


## The page's flow lines ([] when no goal asks for goods and the view is closed).
static func lines(s) -> Array:
	var out: Array = []
	var goal: Dictionary = Needs.goal_goods(s)
	var goals: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	if at < goals.size():
		var sum := GoalSums.line(s, goals[at])
		if sum != "":
			out.append("AT THIS RATE: " + sum)
	for id in Needs.goal_short(s):
		var held := FlowView.bottleneck(s, id)
		var line: String = held["line"]
		if held["pos"] != FlowView.NONE:
			line += " (at (%d,%d))" % [held["pos"].x, held["pos"].y]
		if held.has("pause"):
			line += ' [press Pause them: {"do":"flow","pause_them":true}]'
		out.append("HELD UP: " + line)
	if _all_open:
		out.append("FLOW VIEW (every good: stock, made, used, net a minute):")
		for r in FlowView.rows(s):
			out.append(_row(r))
		_all_open = false
	elif not goal.is_empty():
		var rows: Array = []
		for id in goal:
			rows.append(_row(FlowView.row(s, id)))
		out.append("FLOW (the goal's goods, a minute): " + "; ".join(rows))
	return out


## One good as "Brick 10 in stock, made 6.0, used 0.0, net +6.0 (1 Kiln, working)".
static func _row(r: Dictionary) -> String:
	var makers: Array = []
	for g in r["makers"]:
		makers.append(FlowView.group_line(g))
	return (
		"%s %d in stock, made %.1f, used %.1f, net %+.1f%s"
		% [
			r["name"],
			r["stock"],
			r["made"],
			r["used"],
			r["net"],
			" (%s)" % ", ".join(makers) if not makers.is_empty() else ""
		]
	)


## Run a flow move. Returns why it was refused, "" when it was taken.
static func move(s, m: Dictionary) -> String:
	if not bool(m.get("pause_them", false)):
		_all_open = true
		return ""
	for id in Needs.goal_short(s):
		var held := FlowView.bottleneck(s, id)
		if held.has("pause"):
			for p in held["pause"]:
				s.set_paused(s.town.building_at[p], true)
			return ""
	return "no building is named by a Pause them button now (the HELD UP lines show when one is)"
