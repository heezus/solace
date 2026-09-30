extends RefCounted
## Small helpers the blocks use to write their state as JSON-safe values and read it back (see RunSave and
## the to_dict / from_dict of each block). A Vector2i becomes [x, y]. A set (a Dictionary of key -> true)
## becomes the array of its keys, in the order they were added, since that order can matter. JSON reads every
## number back as a float, so the readers cast: ints come back as ints. Static, and holds no state.


## [x, y] for a tile position.
static func vec(p: Vector2i) -> Array:
	return [p.x, p.y]


static func to_vec(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


## [x, y] for a position between tiles.
static func vec2(p: Vector2) -> Array:
	return [p.x, p.y]


static func to_vec2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## A list of tile positions as a list of [x, y], same order.
static func vec_list(list: Array) -> Array:
	var out: Array = []
	for p in list:
		out.append(vec(p))
	return out


static func to_vec_list(a: Array) -> Array:
	var out: Array = []
	for pair in a:
		out.append(to_vec(pair))
	return out


## The keys of a set of tile positions (Vector2i -> true), as [x, y] pairs in the order they were added.
static func vec_keys(members: Dictionary) -> Array:
	return vec_list(members.keys())


static func to_vec_set(a: Array) -> Dictionary:
	var out := {}
	for pair in a:
		out[to_vec(pair)] = true
	return out


## The keys of a set of names, in order.
static func keys(members: Dictionary) -> Array:
	return members.keys()


static func to_set(a: Array) -> Dictionary:
	var out := {}
	for id in a:
		out[String(id)] = true
	return out


## A copy of an id -> count dictionary with every count an int (order kept).
static func int_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for id in d:
		out[String(id)] = int(d[id])
	return out


## A copy of an id -> number dictionary with every number a float (order kept).
static func float_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for id in d:
		out[String(id)] = float(d[id])
	return out


## A copy of a list with every entry a String.
static func strings(a: Array) -> Array:
	var out: Array = []
	for id in a:
		out.append(String(id))
	return out


## Turn a string-keyed dictionary's values that are Vector2i (the keys named in `points`) into [x, y].
static func with_points(d: Dictionary, points: Array) -> Dictionary:
	var out := d.duplicate(true)
	for key in points:
		if out.has(key):
			out[key] = vec(out[key])
	return out


## The reverse of with_points: those keys' [x, y] back to Vector2i.
static func from_points(d: Dictionary, points: Array) -> Dictionary:
	var out := d.duplicate(true)
	for key in points:
		if out.has(key):
			out[key] = to_vec(out[key])
	return out
