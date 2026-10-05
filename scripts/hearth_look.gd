extends RefCounted
## How far the Hearth has grown, for the artist's staged props (docs/art/requests.md, "Hearth upgrades"). Worked out
## from the techs researched, never stored: no costs, capacity or rules ride on it, and a loaded run shows the same
## Hearth. Stage 0 is the bare camp; each milestone tech adds one stage: a lit fire, seats for the stories, the
## first roofs, the standing calendar, the bronze banner. Static.

## The techs that each add a stage, in the order the Hearth should visibly grow.
const MILESTONES := ["fire", "storytelling", "shelter", "calendar", "bronze_dawn"]


## The Hearth's stage (0 to MILESTONES.size()) once `researched` (tech id -> true) is known.
static func stage(researched: Dictionary) -> int:
	var n := 0
	for tech in MILESTONES:
		if researched.has(tech):
			n += 1
	return n


## The milestone techs reached, in order, so a draw call can say which props to show.
static func reached(researched: Dictionary) -> Array:
	return MILESTONES.filter(func(tech): return researched.has(tech))
