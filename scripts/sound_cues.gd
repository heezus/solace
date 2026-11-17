extends RefCounted
## The sound cue bus. A block that does something worth hearing (a workshop finishing a cycle, a hauler setting a load down, the
## Bloom taking a building) says so with `SoundCues.add("craft", tile)`; main's Sound node takes the list every frame and plays
## what it likes. Nothing here is saved, and nothing is kept unless a Sound node is listening, so the simulation, the tests and
## the bots never fill it. Static, so a block needs no reference to the sound.

const WOODEN := ["wood", "charcoal"]
const ROCKY := ["stone", "flint", "clay", "copper_ore", "tin", "coal", "iron_ore", "shard"]
const CAP := 64  # cues kept between two frames; the oldest go first, so a burst can never grow the list

static var listening := false  # set by the Sound node while it is in the tree
static var queue: Array = []  # {id: String, at: Vector2i}; at (-1, -1) means "no place" (heard at full volume)


## Note that `id` happened at tile `at` (leave `at` out for a sound with no place on the map).
static func add(id: String, at := Vector2i(-1, -1)) -> void:
	if not listening:
		return
	if queue.size() >= CAP:
		queue.pop_front()
	queue.append({"id": id, "at": at})


## Note that `item` was gathered at tile `at`: wood chops, rock and ore knock, everything else is picked.
static func gather(item: String, at: Vector2i) -> void:
	var id := "gather_berries"
	if item in WOODEN:
		id = "gather_wood"
	elif item in ROCKY:
		id = "gather_stone"
	add(id, at)


## Hand over the cues noted since the last call, and forget them.
static func take() -> Array:
	var out := queue
	queue = []
	return out


## Forget everything (a new Sound node, or one leaving the tree).
static func clear() -> void:
	queue = []
