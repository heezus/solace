extends RefCounted
## Era 5, Livewire, stage 1: wires and orders (design-system/23-livewire.md). The words and numbers of the era's opening, the
## net of Power Poles, the Order Board and the standing orders. Read through the `Data` facade (scripts/data.gd). The tech tree
## is in scripts/data/livewire/techs.gd. Every number is a first guess to tune with the pacing bot.

# --- The opening ---
## The story id recorded the first tick after the Wires Hum card is put away (Story.update): the era is entered. Techs with
## `after` (Data.TECHS) stay out of view until it has happened.
const LIVEWIRE_BEGUN := "livewire_begun"
const ERA_TAB_LOCKED_LIVEWIRE := "Opens when the wires hum"

# --- The net ---
## Poles within POLE_LINK tiles of one another join into a net. A machine (a building with `needs_power`) or an engine (a "power"
## building) within POLE_REACH tiles of a pole is on that pole's net: the machine draws from it, the engine feeds it.
const POLE_LINK := 3.0
const POLE_REACH := 2.0
## A machine asks MACHINE_ASK units while it works. An engine gives its `gives` (Data.BUILDINGS): a Water Wheel 2, a Boiler 3 while
## lit, a Generator 8 while lit. A net that gives less than its machines ask runs them all at the ratio.
const MACHINE_ASK := 1

# --- Standing orders ---
const ORDER_SLOTS := 3  # what the Board gives
const ORDER_SLOTS_FOREMEN := 3  # the Foremen tech adds these (stage 2)
const ORDER_SLOTS_CHAIN := 3  # and Chain Orders (stage 3)
## The orders are read this often (seconds of game time), so the rules cost the simulation next to nothing.
const ORDER_EVAL_SECONDS := 3.0
## An order that has not fired for this long is marked, so a mistake is easy to spot.
const ORDER_STALE_SECONDS := 300.0
## An order writes to the event feed at most once in this many seconds.
const ORDER_FEED_SECONDS := 60.0
## While a Bring first order's good is out of the stockpile and a building it names wants some, other buildings are kept from the
## rest of that good for this long; then the claim is skipped, so a rule can never stall a hauler.
const BRING_SKIP_SECONDS := 60.0
## The numbers a When can take, stepped through with the - and + buttons (there is no typing).
const ORDER_NUMBERS := [5, 10, 20, 30, 40, 60, 80, 100, 150, 200, 300, 500]
const ORDER_COMPARES := ["below", "above"]
## The verbs. `pausable` verbs act on a building that has a job; `bring` on one that haulers serve.
const ORDER_VERBS := {
	"pause":
	{"name": "Pause", "tip": "Workshops and mines finish the job they are on, then wait, while the rule holds."},
	"bring":
	{"name": "Bring first", "tip": "Haulers serve these buildings ahead of the rest, and keep the good for them."},
}
const ORDER_VERB_ORDER := ["pause", "bring"]
## A new order starts as this (the first good that has been seen, the first building that can take the verb).
const ORDER_START_ITEM := "coal"
const ORDER_START_NUMBER := 20

# --- Words: the net ---
const NET_LINE := "On a net: %d units given, %d asked"  # given, asked
const NET_RATIO := "Net short by %d: every machine on it runs at %d%%"  # the shortfall, the ratio
const NET_SHORT_ALERT := "Net short by %d"
const NET_DARK := "No power: nothing on this net gives any. Fuel a Boiler or a Generator within 2 tiles of a pole on it"
const NET_NONE := "Not on a net: stand it within 2 tiles of a Power Pole"
const NET_BANKED := "Banked: the net asks for no more than the others give · %d in store"
const NET_SLOW := "Working slowly: the net is short, so %d%% speed"  # the ratio
const NET_ENGINE := "Gives its net %d units while it burns"
const POLE_STATUS := "Net of %d poles · %d machines, %d engines · %d given, %d asked"
const POLE_ALONE := "A pole on its own: lay another within 3 tiles, and a machine or an engine within 2 tiles of a pole"

# --- Words: the orders ---
const ORDER_HEADING := "Standing orders"
const ORDER_EMPTY := "No orders yet. An order is one line: when a good in the stores is below or above a number, do one thing."
const ORDER_SLOTS_LINE := "%d of %d orders written"  # written, allowed
const ORDER_WHEN := "When %s is %s %d: %s"  # a good, below or above, the number, what is done
const ORDER_PAUSE_TEXT := "Pause %s"  # a kind of building, plural
const ORDER_BRING_TEXT := "bring %s first to %s"  # the good, a kind of building, plural
const ORDER_NO_TARGET := "choose a kind of building"
const ORDER_NEW := "Write an order"
const ORDER_FULL := "All %d orders are written. Clear one to write another."
const ORDER_CLEAR := "Clear"
const ORDER_ITEM_TIP := "Click to change the good it reads."
const ORDER_COMPARE_TIP := "Click to switch between below and above."
const ORDER_NUMBER_LESS := "-"
const ORDER_NUMBER_MORE := "+"
const ORDER_NUMBER_TIP := "How many in the stores."
const ORDER_VERB_TIP := "Click to change what it does."
const ORDER_TARGET_TIP := "Click to change the kind of building."
const ORDER_CLEAR_TIP := "Tear this order up."
const ORDER_NEVER := "Has not fired yet"
const ORDER_NOW := "Holding now"
const ORDER_LAST := "Last fired %s ago"  # a duration
const ORDER_STALE := "Has not fired for %s: is it what you meant?"  # a duration
const ORDER_NO_BOARD := "The orders wait: there is no Order Board standing."
const ORDER_FIRED_LINE := "Standing order: %s"  # the order's text
const ORDER_PAUSED_STATUS := "Held by a standing order: it waits until the rule stops holding"
const ORDER_PAUSED_ALERT := "Held"
const ORDER_PAUSED_NOTE := "A standing order holds this: it finishes the job it is on and then waits."
const BOARD_STATUS := "%d of %d orders written · %d holding now"  # written, allowed, holding

# --- Goals ---
const GOALS_HEADER_ERA5 := "Livewire goals %d/%d"
const GOALS_LIVEWIRE_CLOSING := "Wires and orders are done. Stage 2, the tide, comes next."
const GOALS_ERA5 := [
	{
		"id": "power_poles",
		"text": "Discover Power Poles: wire carries power past a Boiler's 5 tiles",
		"tech": "power_poles"
	},
	{
		"id": "poles_laid",
		"text": "Lay two Power Poles within 3 tiles of each other (Logistics tab): they join into a net"
	},
	{
		"id": "net_machine",
		"text":
		"Put a machine and an engine on one net: each within 2 tiles of a pole (a Forge or Grindstone, and a Boiler or Wheel)"
	},
	{
		"id": "generator",
		"text": "Discover Generator, then build one on a net (Workshops tab): 8 units for a net, on coal",
		"building": "generator"
	},
	{"id": "wire_made", "text": "Build a Wire Mill (Metal tab) on a net and make the first Wire from Copper"},
	{
		"id": "order_board",
		"text": "Discover Order Board, then build it near the Hearth (Lore tab)",
		"building": "order_board"
	},
	{"id": "first_order", "text": "Write a first standing order at the Board: pick a good, a number and a verb"},
	{"id": "order_fired", "text": "Watch an order fire: the event feed says so when its rule holds"},
]
