extends RefCounted
## Era 5, Livewire, stage 3: factories and the end (design-system/23-livewire.md). The numbers and words of the Factory Floor, the
## Shard Dynamo, Chain Orders and the Skyward gate, with the era's last goals. Read through the `Data` facade (scripts/data.gd).
## Every number is a first guess to tune with the pacing bot.

# --- The Factory Floor ---
const FLOOR_SPEED := 3.0  # a Floor runs its recipe this many times as fast as the workshop it copies, and eats as fast
const FLOOR_RECIPE_BUTTON := "Recipe: %s"  # the good it makes
const FLOOR_RECIPE_TIP := "Click to change what the Floor makes."
const FLOOR_MAKING := "Making %s at %d times a workshop's speed"  # the good, a multiple
const FLOOR_ROW := "Runs one recipe (Rope, Bricks, Iron, Steel or Wire) at %d times a workshop's speed, and eats its inputs as fast"

# --- Chain Orders ---
const ORDER_WHILE_NONE := "While: always"
const ORDER_WHILE := "While order %d holds"  # an order's number, from 1
const ORDER_WHILE_TIP := "Click to make this order wait on another: it is read only while that one holds."
const ORDER_WHILE_TEXT := " (only while order %d holds)"  # an order's number, from 1

# --- The Skyward gate ---
## The south land: rows this far below the Hearth's row, and further.
const SOUTH_ROWS_BELOW_HEARTH := 8
const DEED_ORDERS := 5  # standing orders written, each with a kind of building chosen
const DEED_LAMPS := 2  # Arc Lamps lit in the south land, with a Scorcher burning there too
const DEED_NAMES := {
	"orders_written": "five standing orders written",
	"south_held": "the south held: a Scorcher burning and two Arc Lamps lit in the south land",
}
## The south goal, its toast and the card's words. The deed is checked live, so a Bloom that darkens a lamp un-ticks the goal and
## says why: "goal_lost" and "now" wrap a goal's or a card's words and the reason, the rest are the reasons.
const SOUTH_LINES := {
	"lost": "The south is no longer held: %s",
	"held": "The south is held again",
	"goal_lost": "%s (lost: %s)",
	"now": "%s (now: %s)",
	"lamps": "%d of %d Arc Lamps lit",
	"no_scorcher": "no Scorcher",
	"unpowered": "Scorcher unpowered",
	"cold": "Scorcher not burning",
}
const SKYWARD_EVENT := "skyward_raised"
const SKYWARD_TITLE := "Skyward"
const SKYWARD_TEXT := (
	"A mast stands over the town with a lamp that never goes out. The hum runs up the wire and into the dark, "
	+ "and far above the south, something answers."
)
const SKYWARD_NOTE := "The age of the wire is done. The game goes on."
const SKYWARD_BUTTON := "Keep building"

# --- Goals (appended to GOALS_ERA5) ---
const GOALS_FACTORIES := [
	{
		"id": "factory_floor",
		"text": "Discover Factory Floor, then build one on a net (Metal tab): one recipe at three times the speed",
		"building": "factory_floor"
	},
	{
		"id": "shard_dynamo",
		"text": "Build a Shard Dynamo on a net (Workshops tab): the Heat plate Lesson makes a Generator of Shards",
		"building": "shard_dynamo"
	},
	{
		"id": "chain_orders",
		"text": "Discover Chain Orders: three more orders, and one can wait on another",
		"tech": "chain_orders"
	},
	{"id": "orders_written", "text": "Write five standing orders, each with a kind of building chosen"},
	{
		"id": "south_held",
		"text": "Hold the south: a Scorcher burning and two Arc Lamps lit in the land south of the Hearth"
	},
	{"id": "skyward", "text": "Discover Skyward, the gate: {cost}", "tech": "skyward"},
]
