extends RefCounted
## The data of the rate gates (Step 9C-2; the logic is scripts/rate_gate.gd): which goods each era gate asks a rate of, how long it must
## be held, and how much of the old pile is still paid. Apart from rate_gate.gd so that scripts/needs.gd can read it without a loop.

const GATES := {
	"bronze_dawn": {"brick": 40, "charcoal": 65, "flour": 12, "rope": 45},
	"falling_star": {"brick": 110, "bronze": 12, "flour": 25, "rope": 75},
	"livewire": {"brick": 120, "iron": 45, "rope": 65, "steel": 11},
	"skyward": {"brick": 95, "iron": 45, "steel": 16, "wire": 20},
}
const HOLD := 60.0  # seconds R must be held
const PILE := 0.25  # of today's price of a rated good, paid at research
const NOT_MADE_BY := ["hand", "craft"]
const KEEP_MINUTES := 3.0  # minutes of a rated good's R the stores keep for the gate away from the Hearthfire


static func is_gate(tech: String) -> bool:
	return GATES.has(tech)


## The goods tech `tech` asks a rate of: {good: R a minute}, {} for a tech that is not a gate.
static func rates(tech: String) -> Dictionary:
	return GATES.get(tech, {})


## The price of `tech` with its rated goods at PILE (rounded, never under 1): the pile paid at research.
static func pile(tech: String, cost: Dictionary) -> Dictionary:
	var out := cost.duplicate()
	for id in rates(tech):
		if out.has(id):
			out[id] = maxi(roundi(float(out[id]) * PILE), 1)
	return out


## The first gate not yet researched ("" when all are): the one the machine is being built for.
static func next_gate(researched: Dictionary) -> String:
	for tech in GATES:
		if not researched.has(tech):
			return tech
	return ""


## The goods the next gate asks a rate of: {good: R}. Makers of these never rest (Goal first, the bots' rests); the Hearthfire leaves them.
static func asked(researched: Dictionary) -> Dictionary:
	return rates(next_gate(researched))


## Of `good` the stores keep for the gate and never give to the Hearthfire: KEEP_MINUTES of R for a rated good, 0 for the others.
static func keep(researched: Dictionary, good: String) -> int:
	return roundi(float(asked(researched).get(good, 0)) * KEEP_MINUTES)
