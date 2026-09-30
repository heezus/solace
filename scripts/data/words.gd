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

# --- The tech board (scripts/tech_panel.gd, scripts/tech_board.gd) ---
const TECH_DONE := "Discovered"

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
const PACE_TRIP := "Each trip brings back %s."  # "6 Berries"
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
