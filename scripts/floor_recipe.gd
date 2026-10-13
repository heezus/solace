extends RefCounted
## Which workshops a Factory Floor can copy (design-system/23-livewire.md): the ones the Kith know how to build, plus the
## one it copies now. Static and Data-only, so both the Buildings logic and the card picker can use it.

const Data = preload("res://scripts/data.gd")


## The workshop types Factory Floor b can copy now. `town` is the Buildings logic (for `unlocked`).
static func options(town, b: Dictionary) -> Array:
	var all: Array = Data.BUILDINGS[b["type"]].get("floor", [])
	return all.filter(func(t): return t == b["make"] or town.unlocked(t))
