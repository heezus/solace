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
const CARD_NEED_MORE := "Need %s +%d more"  # "4 Wood", how many other items are short
const CARD_NEED_ITEMS := "Need more"  # when even the short form doesn't fit
const CARD_DISCOVER := "Discover %s"  # a tech's name

# --- The tech board (scripts/tech_panel.gd, scripts/tech_board.gd). One verb for techs: Discover. ---
const BOARD_TITLE := "Tech tree  ·  Stone Age"
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
const JOBS_TIP := "%s\n%s work buildings and haul goods. Each building is one job and needs one. They grow with spare food and room."
const IDLE_WORD := "idle"
const HAUL_WORD := "hauling"
const NOTE_STARVING := "Starving: no food"
const NOTE_NO_ROOM := "No room: build a Dwelling"
const NOTE_NEEDS_FOOD := "Needs %d spare food to grow"

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

# --- Messages (scripts/main.gd, scripts/messages.gd) ---
const UNLOCKED_TOAST := "%s unlocked: %s tab"  # "Gatherer's Hut", "Gathering"
const LOG_BUTTON := "Messages"
const LOG_TIP := "The last messages (L)"

# --- The building panel (scripts/building_panel.gd) ---
const WORKER_HERE := "%s works here."  # "Aro the Woodcutter"
const WORKER_TOOL := "Their flint tool has %d uses left."
const WORKER_NO_TOOL := "They have no flint tool: craft Flint Tools to work %d%% faster."
const WORKER_NONE := "No one works here yet: waiting for a free %s."  # one
const WORKER_PAUSED := "Paused: no %s works here."  # one
const PACE_TRIP := "Each trip brings back %s, one kind at a time."  # "3 Wood, 3 Stone"
const PACE_WORK := "About %s s of work a trip, plus the walk."
const PACE_MAKES := "Makes about %s %s a minute."  # "15", "Rope"
const PACE_BOOST := "Sped up by %s."  # "Flint Tools (+50%)"
const PACE_TIP := "Exact numbers: %s"
const TRIPS_HINT := "Click the hut to send its %s for a bundle. Trips waiting: %d of %d."  # one
const RUSH_HINT := "Click to finish this cycle now (then %d s to recover)."
const RUSH_WAIT := "Click to finish a cycle early while it's working."
const RUSH_COOL := "Rush ready in %d s."
const HOLDING := "Holding %d of %d"
const CLOSE_TIP := "Close (Esc)"
const SELECT_HINT := "Click a building to see its details here."

# --- The Info panel (scripts/hover_text.gd) ---
const UNEXPLORED_INFO := "Unexplored. Build a Gatherer's Hut, or discover Scouting, to see farther."
