extends RefCounted
## The Teardown block (design-system/19-ironfall.md, stage 2): the parts the Kith hold, the Teardown Bench that opens them and
## the Lessons they keep. A part is a whole one-off object (Data.PARTS), never a pile: it lives in the `pack` at the Hearth
## until a hauler carries it to the Bench, then on the `bench` (a short queue, Data.BENCH_SLOTS), and the Bench takes the
## front one apart in Data.BENCH_SECONDS. That consumes the part and teaches its Lesson for good (`lessons`); a part whose
## Lesson is already known is only stripped for scrap (a little Iron) in Data.SCRAP_SECONDS, so no Lesson can be learned twice.
## Where parts come from (the Wreck, the Lumen Camp, the Bloom patches) is scripts/teardown_finds.gd; what a Lesson does is
## read off `knows()` by the code it changes (Bonuses, Patch, Hands, Buildings, the map overlays).
## Signals: said(message) is a line for the event log; moment(id) is a story moment (Data.STORY_EVENTS) for Story.

signal said(message: String)
signal moment(id: String)

const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Economy = preload("res://scripts/economy.gd")

var pack: Array = []  # part ids at the Hearth, in the order haulers will carry them (a click on a part moves it to the front)
var bench: Array = []  # part ids on the Bench, the front one being taken apart
var progress := 0.0  # seconds spent on the front part
var lessons: Array = []  # Lesson ids learned, in the order they were learned
var wreck_taken: Array = []  # parts the Wreck has handed over (Data.WRECK_PARTS)
var gifts := 0  # parts the Lumen Camp has handed over (the first `gifts` of Data.CAMP_PARTS for the lean)
var gift_clock := 0.0  # seconds since the Camp last handed one over
var sampled: Array = []  # Bloom sample kinds taken (Data.BLOOM_KINDS)
var _town: Buildings
var _stock: Economy


func _init(town: Buildings, stock: Economy) -> void:
	_town = town
	_stock = stock


## True while a Teardown Bench stands.
func has_bench() -> bool:
	return bench_building() >= 0


## The index in the town's building list of the Teardown Bench, -1 for none.
func bench_building() -> int:
	for i in _town.buildings.size():
		if _town.buildings[i]["type"] == "teardown_bench":
			return i
	return -1


## True once the Lesson `id` is learned.
func knows(id: String) -> bool:
	return id in lessons


## True while the town holds the part `id`, in the pack or on the Bench.
func holds(id: String) -> bool:
	return id in pack or id in bench


## "learned", "found" (a part is in the pack or on the Bench) or "locked" (no part yet): the Lessons list's three states.
func lesson_state(id: String) -> String:
	if knows(id):
		return "learned"
	return "found" if holds(id) else "locked"


## Put a part in the pack.
func add_part(id: String) -> void:
	assert(Data.PARTS.has(id), "unknown part " + id)
	pack.append(id)


## Move the first copy of part `id` in the pack to the front: it is the next one haulers carry. False when none is there.
func prioritize(id: String) -> bool:
	var at := pack.find(id)
	if at < 0:
		return false
	pack.remove_at(at)
	pack.push_front(id)
	return true


## The part haulers should carry next: the first in the pack that no hauler (`on_the_way`, the ids) already has,
## "" when there is none or the Bench has no room for another.
func next_to_carry(on_the_way: Array) -> String:
	if not has_bench() or bench.size() + on_the_way.size() >= Data.BENCH_SLOTS:
		return ""
	var carried := {}  # copies of each id already on their way: the first ones in the pack
	for id in on_the_way:
		carried[id] = int(carried.get(id, 0)) + 1
	for id in pack:
		if int(carried.get(id, 0)) > 0:
			carried[id] -= 1
			continue
		return id
	return ""


## The part ids haulers are carrying to the Bench now (their `part` tasks).
static func flying(kith: Array) -> Array:
	var out: Array = []
	for k in kith:
		if k["task"].get("kind", "") == "part":
			out.append(k["task"]["part"])
	return out


## A hauler (or a Kith on foot) set part `id` on the Bench: it leaves the pack. False when it is not there or the Bench is full.
func deliver(id: String) -> bool:
	var at := pack.find(id)
	if at < 0 or bench.size() >= Data.BENCH_SLOTS:
		return false
	pack.remove_at(at)
	bench.append(id)
	return true


## True when the front part will be stripped for scrap, not opened: its Lesson is learned already.
func scrapping() -> bool:
	return not bench.is_empty() and knows(bench[0])


## Seconds the front part takes.
func duration() -> float:
	return Data.SCRAP_SECONDS if scrapping() else Data.BENCH_SECONDS


## Seconds left on the front part, 0 when the Bench is empty.
func seconds_left() -> float:
	return maxf(duration() - progress, 0.0) if not bench.is_empty() else 0.0


func tick(delta: float) -> void:
	var at := bench_building()
	if at < 0:
		if not bench.is_empty():  # the Bench was torn down: its parts go back to the pack
			pack.append_array(bench)
			bench.clear()
		progress = 0.0
		return
	var b: Dictionary = _town.buildings[at]
	if bench.is_empty():
		progress = 0.0
		b["status"] = Data.BENCH_WAITING
		return
	progress += delta
	if progress >= duration():
		_finish()
		b["status"] = Data.BENCH_WAITING
		return
	var name: String = Data.PARTS[bench[0]]["name"]
	var line: String = Data.BENCH_STRIPPING if scrapping() else Data.BENCH_WORKING
	b["status"] = line % [name, ceili(seconds_left())]


## The front part is done: its Lesson is learned, or it gives scrap.
func _finish() -> void:
	var id: String = bench.pop_front()
	progress = 0.0
	var part: Dictionary = Data.PARTS[id]
	if knows(id):
		_stock.add("iron", Data.SCRAP_IRON)
		said.emit(Data.SCRAP_LINE % [part["name"], Data.SCRAP_IRON])
		return
	lessons.append(id)
	said.emit(Data.PART_OPENED_LINE % [part["name"].to_lower(), Data.LESSONS[id]["teaches"]])
	moment.emit("teardown_lesson")


# --- Save --------------------------------------------------------------------


func to_dict() -> Dictionary:
	return {
		"pack": pack.duplicate(),
		"bench": bench.duplicate(),
		"progress": snappedf(progress, 0.001),
		"lessons": lessons.duplicate(),
		"wreck_taken": wreck_taken.duplicate(),
		"gifts": gifts,
		"gift_clock": snappedf(gift_clock, 0.001),
		"sampled": sampled.duplicate(),
	}


## Restore what to_dict wrote. A save from before Teardown has none of it: the block starts empty.
func from_dict(d: Dictionary) -> void:
	pack = _known(d.get("pack", []))
	bench = _known(d.get("bench", []))
	progress = float(d.get("progress", 0.0))
	lessons = _known(d.get("lessons", []))
	wreck_taken = _known(d.get("wreck_taken", []))
	gifts = int(d.get("gifts", 0))
	gift_clock = float(d.get("gift_clock", 0.0))
	sampled = Codec.strings(d.get("sampled", []))


## The part ids in `a` that this build knows, as Strings, in order.
static func _known(a: Array) -> Array:
	return Codec.strings(a).filter(func(id): return Data.PARTS.has(id))
