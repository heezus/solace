extends RefCounted
## Words the interface says: build-card lines, message texts, flavor lines and short explanations. All
## player-facing wording that isn't tied to one thing (an item, a tech, a building) lives here, so it can be
## reworded, or swapped for another faction, without touching engine code. Read through the `Data` facade
## (scripts/data.gd). A `%s` is filled in by the caller; the noun for the people comes from Data.PEOPLE.

# --- Build cards (scripts/card_text.gd) ---
const CARD_READY := "Ready"
const CARD_DRAG := "Drag to lay"
const CARD_PLACING := "Placing"
const CARD_LOCKED := "Locked"
const CARD_NEED := "Need %s"  # "4 Wood, 2 Rope"
const CARD_NEED_NAMES := "Need %s"  # "Wood, Stone": what is short, without the amounts (they are in the price)
const CARD_NEED_COUNT := "Need %d items"  # how many kinds are short, when even the names do not fit
const DEMOLISH_TIP := "Demolish: click a building to remove it, or a resource tile to clear it (X). Buildings refund half."
const DEMOLISH_LABEL := "Demolish"
const CAMERA_HINT := "Arrows or WASD move the map, the wheel zooms, Home returns to the Hearth."
const CARD_NEED_ITEMS := "Need more"  # when even the short form doesn't fit
const CARD_DISCOVER := "Discover %s"  # a tech's name
const CARD_DISCOVER_IT := "Discover it first"  # on a locked card whose tech has the card's own name

# --- The tech board (scripts/tech_panel.gd, scripts/tech_board.gd). One verb for techs: Discover. ---
const BOARD_TITLE := "Tech tree  ·  %s"  # an era's name
# --- A few warm lines at the first moments (scripts/main.gd shows each once) ---
## Story id (Data.STORY_EVENTS) -> the line said when it first happens.
const FLAVOR_STORY := {
	"first_lesson": "The first lesson is learned. What one Kith knows, the Hearth will soon know.",
	"first_trip": "The first hut is at work. The Hearth grows stronger.",
}
const FLAVOR_STOCK_ITEM := "berries"
const FLAVOR_STOCK_AMOUNT := 20
const FLAVOR_STOCK := "A good stock of berries. Nobody goes to sleep hungry tonight."

# --- The top-left readout (scripts/top_bar.gd, scripts/ui.gd) ---
const KITH_LABEL := "%s %d  ·  homes for %d"  # people (many), how many, housing
const JOBS_LABEL := "Jobs filled %d of %d  ·  %d %s"  # working, jobs, the rest, IDLE_WORD or HAUL_WORD
const JOBS_TIP := (
	"%s\n%s work buildings and haul goods. Each building is one job and needs one. "
	+ "They grow when there is room and steady food."
)
## The build card's note on a production building that already stands: copies standing, the percent more it costs.
const COPY_COST_NOTE := "%d standing: this one costs %d%% more."
const IDLE_WORD := "idle"
const HAUL_WORD := "hauling"
const NOTE_STARVING := "Starving: no food"
const NOTE_NO_ROOM := "No room: build a Dwelling"
# --- How close steady food is to the next birth (scripts/growth_note.gd), the Food readout's second line ---
const GROW_NEXT := "Next %s in about %s"  # one, a time ("12 s")
const GROW_STEADY := "Steady food %d of %d s, then a %s in about %s"  # seconds held, seconds wanted, one, a time
const GROW_COUNTING := "Counting what your huts bring in: %d of %d s"  # seconds counted, window
const GROW_NEEDS_MORE := "Needs +%s more food a minute to grow"  # a number
const GROW_NEEDS_STOCK := "Needs %d more food in the stockpile to grow"
## The same, in full, for the Food readout's tooltip (a number, then PEOPLE["many"], then a number).
const GROW_FLOW_TIP := "Huts and workshops bring in %s food a minute; the %s eat %s a minute. Hands and foraging don't count."

const TECH_DONE := "Discovered"
const DISCOVERED_EVENT := "Discovered %s"  # a tech's name: the one verb for research, in toast, log, goals and cards
const TECH_OPTIONAL := "optional"
const HIDDEN_CARD_HINT := "Click the Strange Stone"
const QUEUE_CAPTION := "QUEUE"
const QUEUE_EMPTY := "Click a far tech to queue its chain"
const STOCK_CAPTION := "YOU HAVE"
const STRIP_READY := "Ready now: %s"  # names
const STRIP_NONE := "Nothing is ready yet: gather what the cards need"
const STRIP_HELP := "Hover a card to see what it needs and what it unlocks. Click one to discover it, or to queue the way there."
const RANK_HELP := "Some techs have optional ranks II and III: click a discovered card to buy the next one."
const RANK_LINE := "Optional upgrades: ranks II and III each give %s. You have rank %s."  # effect, "I" or "none yet"
const RANK_NONE := "none yet"
const COUNTER := "%d of %d discovered  ·  %d ready"
const DISCOVER_BUTTON := "Discover %s"
const QUEUED := "Queued"
const QUEUE_BUTTON := "Queue the way there"
const STATE_DONE := "discovered"
const STATE_READY := "ready"
const STATE_MORE := "gather more"
const STATE_LOCKED := "locked"

# --- The research board's two views: "What to learn next" and the whole board (scripts/tech_panel.gd) ---
const VIEW_NEXT := "What to learn next"
const VIEW_ALL := "Whole board"
const VIEW_NEXT_TIP := "Only the techs you can discover right now, and what each one costs"
const VIEW_ALL_TIP := "Every tech in this age, and what leads to what"
const EXPLAIN_NEXT := (
	"These are the techs you can discover right now: everything each one needs is already discovered."
	+ " The gold one is the one we suggest."
)
const EXPLAIN_ALL := (
	"What leads to what in this age. Light lines are done, dark are still needed, 'or' means either parent."
	+ " Drag to move, wheel to zoom, F to fit."
)
const FIT_BUTTON := "Fit (F)"
const FIT_TIP := "Show the whole board at once (F)"
const ZOOM_IN_TIP := "Zoom in (wheel up, or +)"
const ZOOM_OUT_TIP := "Zoom out (wheel down, or -)"
const GATE_NEEDS := "NEEDS ALL %d"  # how many (the tall card at the end of an age)
const GATE_MET := "ALL MET"
const GATE_COUNT := "%d of %d done"
const GATE_COST := "COST"

# --- "What to learn next" (scripts/tech_next.gd, scripts/tech_next_view.gd) ---
const NEXT_NONE := "Nothing new to learn yet. Gather something new by hand, like flax or clay, and more ideas will show up."
const NEXT_ALL_DONE := "Every tech in this age is discovered."
const NEXT_SUGGESTED := "Suggested"
## The rule behind "Suggested", in the badge's tooltip. Keep it in step with TechNext.suggested().
const NEXT_RULE := (
	"We suggest the next step toward the goal you queued, or else toward the tech your Goals list asks for."
	+ " With neither, the cheapest one you can pay for now; and if you can pay for none, the one you are closest to."
)
const NEXT_WHY_QUEUED := "It is the goal you queued."
const NEXT_WHY_QUEUED_ROUTE := "On the way to %s, the goal you queued."  # a tech's name
const NEXT_WHY_LIST := "Your Goals list asks for it."
const NEXT_WHY_LIST_ROUTE := "On the way to %s, which your Goals list asks for."  # a tech's name
const NEXT_WHY_CHEAP := "The cheapest one you can pay for right now."
const NEXT_WHY_CLOSE := "You are closest to paying for this one."
const NEXT_UNLOCKS := "Unlocks: %s"  # one short sentence (TECH_BLURBS)
const NEXT_COST_HEAD := "Costs:"
const NEXT_COST_ITEM := "%s %d of %d"  # an item's name, how many you have, how many it needs
const NEXT_ENOUGH := "You have enough for this."
const NEXT_SHORT := "Still need %s."  # "3 Wood, 2 Stone"
const NEXT_QUEUE := "Queue it"
const NEXT_QUEUE_TIP := "Discovers it for you as soon as you can pay."
const LOCKED_HEADING := "Locked for now"
const LOCKED_NOTE := "Each of these waits on something first."
const LOCKED_NEEDS := "needs %s first"  # "Fire", "Fire and Masonry", "one of Fire or Masonry"
const LOCKED_MORE := "And %d more further on: see the whole board."

## What each tech unlocks, in one short plain sentence (the "What to learn next" cards).
const TECH_BLURBS := {
	"foraging": "Berries gather twice as fast.",
	"knapping": "Lets you craft Flint Tools, so harvests go faster.",
	"cordage": "Lets you make Rope, and build a Twine Post.",
	"fire": "Lets you build a Charcoal Pit that turns wood into charcoal.",
	"storytelling": "New Kith are born 25% faster.",
	"gatherers_hut": "Lets you build a Gatherer's Hut, a building whose worker gathers what is near.",
	"water_wheel": "Lets you build a Water Wheel that powers machines near the river.",
	"masonry": "Dressed stone, which millstones, paved roads and megaliths need.",
	"shelter": "Each Dwelling houses 5 Kith instead of 3.",
	"pottery": "Lets you build a Kiln that fires clay and charcoal into brick.",
	"ochre": "Gatherer's Huts bring back twice the Clay per trip.",
	"star_lore": "Lets you raise a Shard Cairn around the Strange Stone.",
	"scouting": "Gatherer's Huts reach 3 tiles instead of 2.",
	"farming": "Lets you plant Fields of grain on open grassland.",
	"haulers": "Idle Kith carry goods around, and you can lay Roads and Wooden Bridges.",
	"storehouse": "Lets you build Storehouses where haulers drop off and pick up goods.",
	"nets": "Lets you build a Fishing Weir on the river bank, for Fish.",
	"grindstone": "Lets you build a Grindstone that grinds grain into flour.",
	"smoking": "Berries are worth 2 food instead of 1.",
	"megaliths": "Lets you raise Standing Stones: buildings beside one work twice as fast.",
	"stone_axe": "You get 3 Wood from each harvest, and land is cleared for Farming.",
	"irrigation": "Fields that touch the river grow twice as fast.",
	"preservation": "The Kith eat 25% less.",
	"carrying_poles": "Haulers carry 20 at a time instead of 10.",
	"paved_roads": "Lets you lay Paved Roads, 3 times faster than open ground, over any road.",
	"baking": "Bake flour into bread: flour is worth 5 food instead of 3.",
	"rafts": "Kith can cross the river without a bridge, slowly.",
	"calendar": "Fields yield 25% more.",
	"bronze_dawn": "The stone age ends and the land opens to the east.",
	"prospecting": "Names the ore in the hills, and lets you dig it by hand, slowly.",
	"tally_sticks": "The message log keeps counts, and every tech costs 10% less.",
	"plough": "Fields yield 50% more.",
	"mining": "Lets you build a Mine on an ore tile, dug by two Kith.",
	"smelting": "Lets you build a Smelter that melts copper ore into Copper.",
	"kilns_ii": "Every Kiln fires twice the Brick each time.",
	"the_wheel": "Lets you build a Cart Shed: a hand cart carries three times the load, on roads.",
	"alloying": "Lets you build a Crucible that pours Copper and Tin into Bronze.",
	"causeways": "Lets you build a Stone Bridge, over a Wooden Bridge or a new crossing: carts can cross it.",
	"markets": "Lets you build a Trading Post to swap goods.",
	"sky_watch": "Lets you build a Watchtower, and names the new light in the sky.",
	"bronze_tools": "Workers with a Bronze Tool are 50% faster than with flint.",
	"granaries": "Housing grows by 1 for every 20 food in store.",
	"bronze_ploughshare": "Fields yield another 50%.",
	"star_charts": "Traces the Wanderer's path across the sky.",
	"falling_star": "The era ends, and the Wanderer comes down.",
}

# --- Era 2 (scripts/sim.gd, scripts/main.gd, scripts/tech_panel.gd) ---
const LAND_GREW_EVENT := "The land opens to the east. Copper lies in the hills; tin is far off, to the north-east"
const ERA_BANNER_TITLE := "BRONZE DAWN"
const ERA_BANNER_TEXT := "The stone age ends, and the land opens east under fog. Press Look east at the map's edge."
## The lasting pointer at the east edge of the map view (scripts/east_pointer.gd): the ore to look for, and the button.
const LOOK_EAST := "Look east: %s >"  # "copper" or "tin"
const LOOK_EAST_TIP := "Moves the view toward the %s, still under fog. Home brings it back to the Hearth."
const LOOK_EAST_ORE := {"copper_hills": "copper", "tin_stream": "tin"}
const TECH_UNBUILT := "Opens in a later age"  # on a card and in the strip of a tech that is not open to the Kith yet
const ERA_TAB_TIP := "The %s tech tree"  # an era's name
const ERA_TAB_LOCKED := "Opens when Bronze Dawn is discovered"
const MINE_TIP := "A Mine standing on it digs without walking: it takes two Kith."
const ORE_PLAIN_HINT := "Discover %s to read what lies in it."  # a tech's name
const WORKER_CREW := "It takes %d %s to work: %d here."  # how many, many, how many are here
const LOG_COUNT := "%s  x%d"  # a message, how many times in a row (Tally Sticks)

const TOOL_WORE_OUT := "A %s wore out"  # a tool's name in the singular: "Flint Tool", "Bronze Tool"

# --- Stage 2 of era 2: the Trading Post, the Wanderer, the era's end ---
const TRADE_UNSET := "Choose what it gives and what it gets: click the lines below."
const TRADE_UNSET_ALERT := "Set a swap"
const TRADE_GIVES := "Gives: %s"  # an item's name, or TRADE_NONE
const TRADE_GETS := "Gets: %s"
const TRADE_NONE := "nothing yet"
const TRADE_TIP := "Click to move on to the next good."

## What the Kith log from a Watchtower, in three moods as the Wanderer comes nearer (scripts/sky.gd).
const WANDERER_SIGHTINGS := [
	[
		"From the tower the Kith watch a new light rise in the east. It is small and warm, and they give it a name.",
		"The Wanderer shows itself again at dusk, a little way along the sky. The children are allowed to stay up.",
		"A pale light drifts over the hills tonight. The Kith say it is a good sign for the harvest.",
	],
	[
		"The Wanderer is brighter than it was. It no longer moves like a star, and the watchers do not say so aloud.",
		"Tonight the Wanderer cast a shadow. A few of the Kith slept outside to see it, and none of them slept.",
		"The dogs will not look up when the Wanderer rises. Neither will the oldest of the Kith.",
	],
	[
		"The Wanderer burns white now, with a tail like a torn banner. The birds have gone quiet.",
		"The Wanderer is over the whole sky by midnight. The watchers keep their eyes on it and their hands on the rail.",
		"It is lower. Everyone on the tower can see that it is lower.",
	],
]
## The sky window on the map (scripts/sky_view.gd): what it says about the light, and the path Star Charts draws.
const WANDERER_NAME := "The Wanderer"
const WANDERER_STATES := ["a faint light", "a bright light", "a burning light"]  # by mood
const WANDERER_PATH := "%s  ·  %d%% of the way"  # a state, how much of its path the Wanderer has crossed
const WANDERER_TIP := "The new light in the sky. Star Charts draws its path, and it is getting closer."
## What the Kith say when Sky Watch names the light (a story moment, scripts/main.gd shows it once).
const WANDERER_NAMED_LINE := "The new light has a name now: the Wanderer. The Kith build a tower to watch it from."

## The end of the era, when The Falling Star is discovered (scripts/era_card.gd).
const ERA_END_TITLE := "THE FALLING STAR"
const ERA_END_TEXT := (
	"The Wanderer grows huge and bright over Solace, and the whole sky holds its breath.\n\n"
	+ "It is not a star. It is coming down."
)
const ERA_END_BUTTON := "Keep building"
const PROFILE_UNSAVED := "The Kith's story could not be kept for the next run."
const ERA_END_NOTE := "The Kith go on. Whatever is coming, the Hearth still needs wood."

# --- Messages (scripts/main.gd, scripts/messages.gd) ---
const UNLOCKED_TOAST := "%s unlocked: %s tab"  # "Gatherer's Hut", "Gathering"
const LOG_BUTTON := "Messages"
const LOG_TIP := "The last messages (L)"

# --- The building panel (scripts/building_panel.gd) ---
const WORKER_HERE := "%s works here."  # "Aro the Woodcutter"
const WORKER_TOOL := "Their %s has %d uses left."  # a tool's name in lower case ("flint tool"), uses
const WORKER_NO_TOOL := "They have no %s: make %s to work %d%% faster."  # "flint tool", "Flint Tools", the share
## A Tool Bench's line in its panel: what it is making (lower case), tools in the stockpile, tools it keeps ready.
const BENCH_MAKING := "Making: %s, %d in stock (keeps %d ready)."
const BENCH_ENOUGH := "Enough %s: %d in stock. It starts again when more are needed."
const WORKER_NONE := "No one works here yet: waiting for a free %s."  # one
const WORKER_PAUSED := "Paused: no %s works here."  # one
const PACE_TRIP := "Each trip brings back %s."  # "6 Berries"
const PACE_WORK := "About %s s of work a trip, plus the walk."
const PACE_MAKES := "Makes about %s %s a minute."  # "15", "Rope"
const PACE_BOOST := "Sped up by %s."  # "Flint Tools (+50%)"
const PACE_TIP := "Exact numbers: %s"

# --- What a Field is for (scripts/field_text.gd): the Info panel, the build card and the placement pill ---
const FIELD_TITLE := "Field (sown %s)"  # an item's name
const FIELD_NO_HUT := "No hut in reach: put a Gatherer's Hut within %d tiles."
const FIELD_HUT_WORKS := "A hut with a worker reaps it: about %s %s a minute from the %d tiles in its reach."
const FIELD_HUTS_WORK := "%d huts reap it: about %s %s a minute together."
const FIELD_HUT_OTHER := "The hut in reach works %s, not %s: click it to switch."  # item, item
const FIELD_HUT_EMPTY := "The hut in reach has no %s to work it yet."  # one
const FIELD_PAYS := "A field pays %d%% more %s a harvest than the wild plant."  # percent, an item's name
const FIELD_PAYS_LATER := "Fields pay more %s a harvest once you discover %s (+%d%%)."  # item, tech name, percent
const FIELD_SOWN_STAYS := "Sown %s never runs out, and counts toward the hut's patch like any tile."  # an item's name
const FIELD_RIVER := "It touches the river: huts harvest it twice as fast."
const FIELD_RIVER_LATER := "It touches the river: %s would make huts harvest it twice as fast."  # tech name
const FIELD_MILL := "%s is not eaten raw: a %s turns %s into %s."  # item, building, "2 Grain", "1 Flour"
const FIELD_CARD := "%d of your %d fields have no hut within %d tiles."  # count, total, radius
const FIELD_CARD_OK := "All %d of your fields are in reach of a hut."  # total
const FIELD_CARD_RULE := "A field pays only through a Gatherer's Hut within %d tiles that works %s."  # radius, an item's name
const FIELD_CARD_NONE := "You have no fields yet."
const FIELD_PLACE_HUT := "In reach of %s: a hut works it."  # "1 hut" / "2 huts"
const FIELD_DRAG_NONE := "no hut in reach"
const FIELD_DRAG_SOME := "%d in reach of a hut"  # tiles

# --- What the tiles in a hut's reach do (scripts/patch_text.gd) ---
## ("1 Clay tile", step, most, tiles) ("4 Clay tiles", now, step, most, tiles) ("6 Clay tiles", most)
const PATCH_ONE := "%s in range: enough to work. Each extra tile adds +%d%% speed, up to +%d%% at %d tiles."
const PATCH_SOME := "%s in range: +%d%% speed. Each extra tile adds +%d%%, up to +%d%% at %d tiles."
const PATCH_FULL := "%s in range: +%d%% speed, the most a patch gives. More tiles will not help this hut."
const PATCH_EXACT := "Patch: %d tiles in reach, Speed x%s"  # tiles, a multiplier
const PATCH_PILL := "%s x%d · +%d%% speed"  # "Clay", tiles, percent
const PATCH_FIELDS := "%d of its %d tiles are Fields."
const PATCH_RATE := "About %s %s a minute while its worker is at it."  # a number, an item's name
## (step, a number, an item's name)
const FIELD_GAIN := "Each field adds +%d%% to the hut's speed: this one is worth about +%s %s a minute."
## (an item's name, a number, an item's name, step)
const FIELD_GAIN_FIRST := "It is the only %s tile this hut has: worth about +%s %s a minute, each extra one adds +%d%% speed."
const FIELD_GAIN_FULL := "The hut already has %d tiles in reach, the most that help: this field adds nothing to it."  # tiles
const TRIPS_HINT := (
	"Click the hut to send its %s out for a round of bundles: until a road links it, it works only when you click it."
	+ " Trips waiting: %d of %d."
)  # one
## Heading the click hint of a food hut while its food is comfortable (formatted with PEOPLE["many"]).
const TRIPS_FED := "Your %s are fed; click to send more anyway."
const RUSH_HINT := "Click to finish this cycle now (then %d s to recover)."
const RUSH_WAIT := "Click to finish a cycle early while it's working."
const RUSH_COOL := "Rush ready in %d s."
const HOLDING := "Holding %d of %d"
const CLOSE_TIP := "Close (Esc)"
const SELECT_HINT := "Click a building to see its details here."

# --- The Info panel (scripts/hover_text.gd) ---
const UNEXPLORED_INFO := "Unexplored. Build a Gatherer's Hut, or discover Scouting, to see farther."
