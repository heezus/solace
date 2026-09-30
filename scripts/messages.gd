extends RefCounted
## The message queue: what the game says to the player. Each message shows as a toast for a few seconds,
## stacked under the others, and every message is kept in a short log (opened with L) so nothing is lost.
## An important one (a Kith left, the food ran out) is sticky: it stays until it is clicked away, or until
## the trouble is over (`resolve`). Pure data with no drawing, so it can be tested on its own; the toasts and
## the log are drawn by scripts/toast_stack.gd and scripts/message_log.gd.

signal changed  # a toast came, went or was dismissed, or the log grew

const Data = preload("res://scripts/data.gd")

const MAX_SHOWN := 4  # toasts on screen at once; the oldest makes room for a new one (it stays in the log)
const LOG_MAX := 60
const MIN_SECONDS := 3.0
const MAX_SECONDS := 9.0

var active: Array = []  # {"id", "text", "left" (seconds), "sticky", "key"}, oldest first
var history: Array = []  # {"text", "at" (seconds of play), "sticky"}, oldest first
var clock := 0.0
var _next_id := 1


## Say something. `seconds` is how long the toast stays (0 = by the length of the text); a sticky message stays until
## dismissed. A message with the same `key` (or, with no key, the same text) already showing is refreshed, not stacked.
func push(text: String, seconds := 0.0, sticky := false, key := "") -> int:
	var secs := seconds if seconds > 0.0 else clampf(2.0 + text.length() * 0.05, MIN_SECONDS, MAX_SECONDS)
	history.append({"text": text, "at": clock, "sticky": sticky})
	if history.size() > LOG_MAX:
		history.pop_front()
	for shown in active:
		if (key != "" and shown["key"] == key) or (key == "" and shown["key"] == "" and shown["text"] == text):
			shown["text"] = text
			shown["left"] = secs
			shown["sticky"] = sticky
			changed.emit()
			return shown["id"]
	var msg := {"id": _next_id, "text": text, "left": secs, "sticky": sticky, "key": key}
	_next_id += 1
	active.append(msg)
	while active.size() > MAX_SHOWN:
		active.remove_at(_oldest_to_drop())
	changed.emit()
	return msg["id"]


## The index of the toast to make room with: the oldest that isn't sticky, or else the oldest.
func _oldest_to_drop() -> int:
	for i in active.size():
		if not active[i]["sticky"]:
			return i
	return 0


## Time passes: toasts run down (a sticky one doesn't) and go when they reach zero.
func advance(delta: float) -> void:
	clock += delta
	for shown in active:
		if not shown["sticky"]:
			shown["left"] -= delta
	var kept := active.filter(func(m): return m["sticky"] or m["left"] > 0.0)
	var gone := kept.size() != active.size()
	active = kept
	if gone:
		changed.emit()


## The player clicked a toast away.
func dismiss(id: int) -> void:
	var kept := active.filter(func(m): return m["id"] != id)
	if kept.size() != active.size():
		active = kept
		changed.emit()


## The trouble a message with this key was about is over: take it down.
func resolve(key: String) -> void:
	var kept := active.filter(func(m): return m["key"] != key)
	if kept.size() != active.size():
		active = kept
		changed.emit()


## Whether a toast with this key is showing.
func showing(key: String) -> bool:
	return active.any(func(m): return m["key"] == key)


## The `n` newest log entries, newest first.
func recent(n: int) -> Array:
	var out: Array = history.slice(maxi(history.size() - n, 0))
	out.reverse()
	return out


## "1:05" for a time in seconds of play.
static func clock_text(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]


## How a message from the simulation shows: {"seconds", "sticky", "key"}. A Kith leaving and the food running
## low are important, so they stay until clicked away (the food ones until the food is back).
static func style_of(text: String) -> Dictionary:
	if text == Data.LEFT_EVENT % Data.PEOPLE["one"]:
		return {"seconds": 0.0, "sticky": true, "key": ""}
	if text == Data.FOOD_LOW_EVENT % Data.PEOPLE["many"]:
		return {"seconds": 0.0, "sticky": true, "key": "food"}
	return {"seconds": 0.0, "sticky": false, "key": ""}
