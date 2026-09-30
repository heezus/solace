extends RefCounted
## The signal monitor from design-system/15-architecture.md: it listens to signals on any object and keeps
## what was emitted, in order, so a test can assert "researching Haulers emitted tech_researched exactly
## once". Methods, not lambdas, take the signals, so a monitor holds nothing of the thing it watches.
## Tests build one, call watch(block, "signal_name"), act, then ask count(), args_of() or names().

var emitted: Array = []  # each: {"name": String, "args": Array}, in the order they were emitted


## Record every emission of `signal_name` on `source`. Up to three signal arguments are supported.
func watch(source: Object, signal_name: String) -> void:
	var argc := -1
	for sig in source.get_signal_list():
		if sig["name"] == signal_name:
			argc = sig["args"].size()
	assert(argc >= 0 and argc <= 3, "cannot watch signal " + signal_name)
	Signal(source, signal_name).connect(Callable(self, "_on%d" % maxi(argc, 0)).bind(signal_name))


## How many times `signal_name` was emitted (all signals when it is left out).
func count(signal_name: String = "") -> int:
	if signal_name == "":
		return emitted.size()
	return names().count(signal_name)


## The signal names emitted so far, in order.
func names() -> Array:
	return emitted.map(func(e): return e["name"])


## The arguments of each emission of `signal_name`, in order: an array of argument arrays.
func args_of(signal_name: String) -> Array:
	var out: Array = []
	for e in emitted:
		if e["name"] == signal_name:
			out.append(e["args"])
	return out


## Forget what was recorded (the watches stay).
func clear() -> void:
	emitted.clear()


func _on0(signal_name: String) -> void:
	emitted.append({"name": signal_name, "args": []})


func _on1(a, signal_name: String) -> void:
	emitted.append({"name": signal_name, "args": [a]})


func _on2(a, b, signal_name: String) -> void:
	emitted.append({"name": signal_name, "args": [a, b]})


func _on3(a, b, c, signal_name: String) -> void:
	emitted.append({"name": signal_name, "args": [a, b, c]})
