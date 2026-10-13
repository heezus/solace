extends RefCounted
## Chain Orders (design-system/23-livewire.md): an order may wait on another, "while order 2 holds", and is read only while that one
## holds. `after` is that order's place in the list counting from 1, or 0 for an order that waits on nothing. Static, and works on
## the orders array of the Livewire block; the Board's panel steps `after` with `cycle`.

const Data = preload("res://scripts/data.gd")


## True when order `o` may be read now: it waits on nothing, or the order it waits on is holding.
static func ready(orders: Array, o: Dictionary) -> bool:
	var after: int = o["after"]
	return after == 0 or (after <= orders.size() and orders[after - 1]["holding"])


## Order i was torn up (already removed): orders that waited on it wait on nothing, and later places move up one.
static func forget(orders: Array, i: int) -> void:
	for o in orders:
		if o["after"] == i + 1:
			o["after"] = 0
		elif o["after"] > i + 1:
			o["after"] -= 1


## Step order i to wait on the next other order, and from the last of them to nothing.
static func cycle(orders: Array, i: int) -> void:
	var o: Dictionary = orders[i]
	var next: int = o["after"] + 1
	if next == i + 1:
		next += 1  # not on itself
	o["after"] = next if next <= orders.size() else 0


## The order's tail in its line: " (only while order 2 holds)", or "".
static func suffix(o: Dictionary) -> String:
	return Data.ORDER_WHILE_TEXT % o["after"] if o["after"] > 0 else ""


## The button's words for order o.
static func button(o: Dictionary) -> String:
	return Data.ORDER_WHILE % o["after"] if o["after"] > 0 else Data.ORDER_WHILE_NONE
