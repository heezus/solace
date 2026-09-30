extends RefCounted
## The game's static data, as one facade: `Data.X` reads a constant from the file for its domain in
## scripts/data/. Add a constant to its domain file and re-export it here (the convention tests fail
## if one is missing or defined twice). Canon lives in the design system (design-system/08-first-playable.md);
## keep names in sync with its glossary.

const DataItems = preload("res://scripts/data/items.gd")
const DataPeople = preload("res://scripts/data/people.gd")
const DataTiles = preload("res://scripts/data/tiles.gd")
const DataTechs = preload("res://scripts/data/techs.gd")
const DataBuildings = preload("res://scripts/data/buildings.gd")
const DataGoals = preload("res://scripts/data/goals.gd")
const DataTuning = preload("res://scripts/data/tuning.gd")

# --- Items: data/items.gd ---
const ITEMS := DataItems.ITEMS
const ITEM_ORDER := DataItems.ITEM_ORDER
const FOOD_VALUE := DataItems.FOOD_VALUE
const EAT_ORDER := DataItems.EAT_ORDER
const SMOKED_BERRY_FOOD := DataItems.SMOKED_BERRY_FOOD
const BAKED_FLOUR_FOOD := DataItems.BAKED_FLOUR_FOOD
const RECIPES := DataItems.RECIPES

# --- People: data/people.gd ---
const PEOPLE := DataPeople.PEOPLE
const BORN_EVENT := DataPeople.BORN_EVENT
const LEFT_EVENT := DataPeople.LEFT_EVENT
const FOOD_LOW_EVENT := DataPeople.FOOD_LOW_EVENT
const FOOD_LOW_TEXT := DataPeople.FOOD_LOW_TEXT
const PEOPLE_NAMES := DataPeople.PEOPLE_NAMES
const HUT_JOBS := DataPeople.HUT_JOBS
const JOB_HAULER := DataPeople.JOB_HAULER
const JOB_IDLE := DataPeople.JOB_IDLE
const CAMP_TOAST := DataPeople.CAMP_TOAST
const BORN_POPUP := DataPeople.BORN_POPUP
const BORN_TOAST := DataPeople.BORN_TOAST
const NAMELESS := DataPeople.NAMELESS
const BRIDGE_HINT := DataPeople.BRIDGE_HINT
const ROAD_HINT := DataPeople.ROAD_HINT
const FOOD_TIP := DataPeople.FOOD_TIP
const STARVING_TEXT := DataPeople.STARVING_TEXT
const TOOLS_LABEL := DataPeople.TOOLS_LABEL
const TOOLS_TIP := DataPeople.TOOLS_TIP
const FOOD_NOTE := DataPeople.FOOD_NOTE
const HUNGRY_THEN := DataPeople.HUNGRY_THEN
const EATEN_BY := DataPeople.EATEN_BY

# --- Tiles: data/tiles.gd ---
const TILES := DataTiles.TILES
const SHARD_TEXT := DataTiles.SHARD_TEXT
const WALK_COST := DataTiles.WALK_COST
const PASS_COST := DataTiles.PASS_COST

# --- Techs: data/techs.gd ---
const LANES := DataTechs.LANES
const LANE_ORDER := DataTechs.LANE_ORDER
const TIER_NAMES := DataTechs.TIER_NAMES
const QUEUE_SLOTS := DataTechs.QUEUE_SLOTS
const MAX_RANK := DataTechs.MAX_RANK
const RANK_COST_STEP := DataTechs.RANK_COST_STEP
const RANK_NAMES := DataTechs.RANK_NAMES
const TECHS := DataTechs.TECHS
const TECH_ORDER := DataTechs.TECH_ORDER

# --- Buildings: data/buildings.gd ---
const BUILDINGS := DataBuildings.BUILDINGS
const BUILD_TABS := DataBuildings.BUILD_TABS
const BUILD_ORDER := DataBuildings.BUILD_ORDER
const BUFFER_CAP := DataBuildings.BUFFER_CAP

# --- Goals: data/goals.gd ---
const STORY_EVENTS := DataGoals.STORY_EVENTS
const STORY_TECHS := DataGoals.STORY_TECHS
const GOALS := DataGoals.GOALS

# --- Tuning: data/tuning.gd ---
const LEARN_CLICKS := DataTuning.LEARN_CLICKS
const BUNDLE := DataTuning.BUNDLE
const TRIP_QUEUE := DataTuning.TRIP_QUEUE
const RUSH_COOLDOWN := DataTuning.RUSH_COOLDOWN
const HOLD_TIME := DataTuning.HOLD_TIME
const HAND_TOOLS := DataTuning.HAND_TOOLS
const FOOD_PER_KITH_PER_SEC := DataTuning.FOOD_PER_KITH_PER_SEC
const START_BERRIES := DataTuning.START_BERRIES
const FOOD_WARN_SECONDS := DataTuning.FOOD_WARN_SECONDS
const FOOD_CLEAR_SECONDS := DataTuning.FOOD_CLEAR_SECONDS
const KITH_START := DataTuning.KITH_START
const GROW_TIME := DataTuning.GROW_TIME
const BIRTH_FOOD := DataTuning.BIRTH_FOOD
const STARVE_TIME := DataTuning.STARVE_TIME
const KITH_SPEED := DataTuning.KITH_SPEED
const CARRY := DataTuning.CARRY
const HEARTH_RADIUS := DataTuning.HEARTH_RADIUS
const SIGHT_START := DataTuning.SIGHT_START
const SIGHT_BUILDING := DataTuning.SIGHT_BUILDING
const SIGHT_KITH := DataTuning.SIGHT_KITH
const SCOUTING_SIGHT := DataTuning.SCOUTING_SIGHT
const RATE_WINDOW := DataTuning.RATE_WINDOW
const FLOW_EAT_SOURCE := DataTuning.FLOW_EAT_SOURCE
const FLOW_TOOL_SOURCE := DataTuning.FLOW_TOOL_SOURCE
const STORYTELLING_GROW := DataTuning.STORYTELLING_GROW
const BONUSES := DataTuning.BONUSES
const TOOL_JOBS := DataTuning.TOOL_JOBS
const CALENDAR_FIELD_BONUS := DataTuning.CALENDAR_FIELD_BONUS
