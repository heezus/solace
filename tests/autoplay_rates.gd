extends RefCounted
## What a bot asks of its machine for the rate gates (Step 9C-2): once the next gate is near, every made good it asks a rate of
## counts as short by that rate until the rate has been held, so the workshops (and the huts that feed them) go up the way a
## player builds more machine when the goal line says "Brick 34 of 40 a min".

const RateData = preload("res://scripts/rate_data.gd")
const RateGate = preload("res://scripts/rate_gate.gd")

const NEAR := 4  # the gate is near when it is among the next techs queued


## Adds to `want` (what the bot is short of, by good) the rate of every made good the next gate asks of it. `maker` maps a made
## good to its workshop. A rate already held, or a gate not yet near, asks nothing.
static func wants(s, want: Dictionary, maker: Dictionary) -> void:
	var gate := RateData.next_gate(s.tech_tree.researched)
	if gate == "" or not gate in s.tech_tree.queue.slice(0, NEAR):
		return
	var rates := RateData.rates(gate)
	for good in rates:
		if maker.has(good) and RateGate.held(s, gate, good) < RateData.HOLD:
			want[good] = maxi(int(want.get(good, 0)), int(s.economy.inv.get(good, 0)) + int(rates[good]))


## The goods `gate` asks a rate of that are not yet held: what its bot never rests the workshops of.
static func unheld(s, gate: String) -> Array:
	var out: Array = []
	var rates := RateData.rates(gate)
	for good in rates:
		if RateGate.held(s, gate, good) < RateData.HOLD:
			out.append(good)
	return out
