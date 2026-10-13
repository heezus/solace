extends RefCounted
## Era 4, Ironfall, stage 3: steam and the end (design-system/19-ironfall.md). The numbers and words of the Boiler, the Shard
## Boiler, the Shard Lamp, Rails and the carts, the Beast Pen, Steel Tools, the Iron Plough, Taught Hands II and the Livewire
## end card. Read through the `Data` facade (scripts/data.gd). Every number is a placeholder to tune with the pacing bot.

# --- Fire: the Boiler, the Shard Boiler and the Shard Lamp ---
## A fed building burns what haulers bring it: a Boiler 1 Coal every BOILER_BURN seconds while a machine in its reach wants
## power, a Shard Boiler 1 Shard every SHARD_BOILER_BURN (far less to carry, and no coal), a Shard Lamp 1 Shard every
## LAMP_BURN and it lights LAMP_LIGHT tiles. The coal in a Boiler is finite in the ground, so a burning Boiler matters.
const BOILER_BURN := 20.0
const SHARD_BOILER_BURN := 80.0
const LAMP_BURN := 300.0
const LAMP_LIGHT := 3
## Past this many seconds a Lantern Party (the Sap Lesson) may stay out beyond the day, while a lit Shard Lamp stands: the
## daylight of Data.DAYLIGHT_SECONDS times this.
const LANTERN_DAYLIGHT := 1.5
## Chipping a shard from the Strange Stone by hand once Shard Lamps is learned: the hold, in seconds (Data.HAND_HOLD).
const SHARD_ITEM := "shard"

# --- Carts ---
## What a hauler's trip carries in a cart, as a multiple of a hauler's load (Data.CARRY): the hand cart 3 (30), the beast cart 3
## (30) and the Steam Cart 4 (40). Carrying Poles double a load as ever.
const BEAST_LOAD := 3
const STEAM_LOAD := 4
## A Steam Cart burns 1 Coal to make STEAM_TRIPS trips; with no coal in the stockpile it goes cold and hauls like a plain hauler.
const STEAM_TRIPS := 3
## A Beast Pen tames its beast over BEAST_TAME seconds, eating one Grain every BEAST_EAT seconds while it does; a tamed beast
## pulls a beast cart for as long as the Pen stands.
const BEAST_TAME := 60.0
const BEAST_EAT := 6.0

# --- Tools and Fields ---
## Steel Tools: they wear slowly (Data.TOOL_JOBS 40, BRONZE 200, IRON 300).
const STEEL_TOOL_JOBS := 600
## The Iron Plough's share of a Field's bundle, on top of the Plough's and the Ploughshare's.
const IRON_PLOUGH_FIELD_BONUS := 0.5
## Taught Hands II: teach-by-doing needs this share of the usual harvests, and a Kith who learns a job also learns any other
## the player has harvested at least this share of that many times.
const TAUGHT_HANDS_II_SHARE := 0.5

# --- Words: the fire ---
const BOILER_LIT := "Burning · %d s of heat left · %d in store"
const BOILER_BANKED := "Banked: no machine within reach wants power · %d in store"
const BOILER_COLD := "Cold: no %s. Haulers bring it from the stockpile"  # the fuel's name
const FUEL_ROW := "Burns 1 %s every %d s while a machine wants power · holds up to %d"  # name, seconds, stock
const LAMP_ROW := "Burns 1 Shard every %d s and lights %d tiles · holds up to %d"
const LAMP_LIT := "Lit · %d s of light left · %d in store"
const LAMP_DARK := "Dark: no Shard. Haulers bring one from the stockpile"
const NO_POWER_STATUS := "No power: build a Water Wheel by the river or a Boiler within 5 tiles"
const LANTERN_LINE := "A Lantern Party may stay out past dusk while a Shard Lamp burns"

# --- Words: carts and rails ---
const CART_KINDS := {
	"hand": "hand cart",
	"beast": "beast cart",
	"steam": "Steam Cart",
}
const STEAM_COLD := "The Steam Cart has no Coal and hauls like a plain hauler"
const RAIL_NOTE := "Rail · 8 times open ground. Steam Carts run only on rail; beast carts keep off it"
const SHED_ROW := "Turns a hauler into a Steam Cart: 40 a trip, only on Rail, 1 Coal for %d trips"
const PEN_TAMING := "Taming the beast · %d%% · %d Grain in store"
const PEN_TAMED := "A tamed beast pulls a beast cart: 30 a trip on roads, no coal, never on Rail"
const PEN_NEEDS := "Needs Grain: haulers bring it from the stockpile"

# --- Words: Taught Hands II and the Shard ---
const SPREAD_LINE := "%s learned %s as well."  # name, the craft
const SHARD_CHIPPED := "+%d Shard"
const SHARD_HINT := "Shard Lamps: hold the mouse on the Strange Stone to chip a Shard from it."

# --- The end of the age: Livewire ---
const LIVEWIRE_EVENT := "livewire_lit"
const LIVEWIRE_TITLE := "The Wires Hum"
const LIVEWIRE_TEXT := (
	"The lamps burn without a flame. The Kith lay their hands on the new wires and feel a hum run down them, "
	+ "steady as a breath. And far to the south, in the fog, something green moves."
)
const LIVEWIRE_NOTE := "The age of iron is done. The game goes on."
const LIVEWIRE_BUTTON := "Keep building"
