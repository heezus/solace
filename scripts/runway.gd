extends RefCounted
## How long a good lasts at the rate it is going down, for the top bar's chips (design-system/24-balance.md, pick 4).
## Pure functions: the bar asks, nothing here holds state.

enum Tone { NONE, AMBER, RED }

const Data = preload("res://scripts/data.gd")


## Seconds a stockpile of `count` lasts at `per_sec` (a net rate, negative while it falls). INF when it is not falling or
## there is nothing to run out of.
static func seconds(count: int, per_sec: float) -> float:
	if count <= 0 or per_sec >= -0.005:
		return INF
	return count / -per_sec


## How loud the chip should be for `left` seconds: red under Data.RUNWAY_RED_SECONDS, amber under RUNWAY_AMBER_SECONDS.
static func tone(left: float) -> Tone:
	if left < Data.RUNWAY_RED_SECONDS:
		return Tone.RED
	return Tone.AMBER if left < Data.RUNWAY_AMBER_SECONDS else Tone.NONE


## "4:10" for 250 seconds, "0:45" for 45; empty when the good is not running out soon.
static func text(left: float) -> String:
	if tone(left) == Tone.NONE:
		return ""
	var s := int(left)
	return "%d:%02d" % [floori(s / 60.0), s % 60]
