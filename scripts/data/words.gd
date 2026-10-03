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
const DEMOLISH_TIP := "Demolish: click a building to remove it (X). Refunds half."
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
const IDLE_WORD := "idle"
const HAUL_WORD := "hauling"
const NOTE_STARVING := "Starving: no food"
const NOTE_NO_ROOM := "No room: build a Dwelling"

const TECH_DONE := "Discovered"
const DISCOVERED_EVENT := "Discovered %s"  # a tech's name: the one verb for research, in toast, log, goals and cards
const TECH_OPTIONAL := "optional"
const HIDDEN_CARD_HINT := "Click the Strange Stone"
const NEXT_NONE := "Nothing new to discover right now. Gather more, or look at the whole board."
const VIEW_NEXT := "Next steps"
const VIEW_ALL := "Whole board"
const VIEW_NEXT_TIP := "Just what you can discover next"
const VIEW_ALL_TIP := "Every tech, and the lines between them"
const QUEUE_CAPTION := "QUEUE"
const QUEUE_EMPTY := "Click a far tech to queue its chain"
const READY_CAPTION := "READY TO DISCOVER"
const READY_EMPTY := "Nothing yet: gather more"
const LEGEND_DONE := "discovered"
const LEGEND_NEEDED := "still needed"
const LEGEND_HOVER := "hover: what it needs and unlocks"
const LEGEND_COST := "costs: you have / it needs"
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
const TRIPS_HINT := (
	"Click the hut to send its %s for a bundle: until a road links it, it works only when you click it."
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
