extends RefCounted
## "Set out early" (fun-4, "no trapped telling"): from Ironfall on, when no goal has moved for STALL_SECONDS, the endings card offers a
## way out even though Skyward does not stand. It ends the telling as an Exodus with half the carry-over (Carry.earned with `half`),
## so a player who is stuck can always move on. Static, and works on the Sim passed in; the card and the menu are in
## scripts/ending_card.gd and scripts/game_menu.gd.

const Data = preload("res://scripts/data.gd")

const STALL_SECONDS := 600.0  # no goal met for this long (game seconds) opens it
const ENDING := "exodus"  # the only ending an early set out can be
const TITLE := "Set out early"
const TEXT := (
	"No goal has moved for a while. The Kith can walk on to a new land now, but they carry only half of what they know:"
	+ " half the techs, half the marks and half the plans."
)
const GIVES := "Gives: half of everything the Kith know"
const CONFIRM := "The town stays behind. The Kith walk out early, and half of what they know is lost on the road."
const TIP := "From Ironfall on, when no goal has moved for ten minutes, you may set out early with half the carry-over."
const OFFER := (
	"SET OUT EARLY is open: no goal has moved for %d min."
	+ ' Move {"do":"set_out","ending":"exodus"} ends the telling with half the carry.'
)


## True once an early set out is on offer: Ironfall has begun, Skyward does not stand yet (then the full card is open) and no goal has
## been met for STALL_SECONDS.
static func open(s) -> bool:
	if not s.story.has_event(Data.IRONFALL_EVENT):
		return false
	var done: String = Data.SKYWARD_EVENT if s.carry.is_first() else Data.SKYREACH["done"]
	return not s.story.events.has(done) and stalled_for(s) >= STALL_SECONDS


## Game seconds since the last goal was met.
static func stalled_for(s) -> float:
	return maxf(s.seasons.time - s.story.last_goal_at, 0.0)
