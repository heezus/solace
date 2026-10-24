extends RefCounted
## The first-time hints (scripts/hints.gd): one short note the first time a new mechanic matters, shown once and never again
## (the ids shown are kept in the profile), off in the pause menu. The stone age and Bronze Dawn ones; each later era adds its own.
## Read through the `Data` facade (scripts/data.gd).

const HINTS_LABEL := "Hints"
const HINTS_HELP := "A short note the first time something new matters. Each shows once. Off hides them all."
const HINT_KIND := "hint"  # the Messages kind of a hint's toast: it stays until it is clicked away
const HINT_KEY := "hint:"  # the key prefix of a hint's toast
const HINT_SHORT_FOR := 60.0  # seconds a job must stand empty with no idle Kith before "not enough hands"
const HINT_GAP_FOR := 30.0  # seconds a red gap must last before the Sight hint

## In the order they are offered when several wait at once. id -> the words.
const HINT_ORDER := [
	"hut",
	"hauler_wait",
	"short_hands",
	"store_full",
	"strain",
	"births_wait",
	"gap",
	"mine",
	"storehouse",
]
const HINTS := {
	"hut": "Huts gather what's in reach. Click one to choose what it gathers.",
	"hauler_wait": "Haulers carry goods to the Hearth. Kith with no job haul; roads make every trip faster.",
	"short_hands": "Not enough hands. Pause a building you don't need right now (P); its Kith go to work elsewhere.",
	"store_full": "Stores are full of this. Workshops rest until there's room; a Storehouse adds room.",
	"strain": "A hard season: watch the warning's clock and have the answer stocked before it runs out.",
	"births_wait": "",  # the same line the top bar shows (Data.NOTE_BIRTHS_WAIT), with the number of idle Kith when it comes
	"gap": "Hold Alt to see where goods move and why a building is stuck.",
	"mine": "Mines dig ore from the hills. Smelters turn ore into metal; both need haulers to keep moving.",
	"storehouse": "A Storehouse is a second Hearth for haulers. Its card shows how many it has and how many it needs.",
}
