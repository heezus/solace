# Genre conventions Solace is missing

Status: **being built in priority order** (2026-09-30).

From the project owner's playtest: "it feels like there are so many ideas based on other games mechanics that are just things you come to expect." This is the list of things a player of Factorio, Timberborn, Anno or Civ assumes a game has, checked against Solace. Defaults were picked by Claude and can be changed.

## P1: Can I read what's happening?
| # | Convention | Seen in | Solace default |
|---|---|---|---|
| 1 | **Rates under every resource**: +/- per minute, green or red | Anno, Factorio | A small line under each top bar item shows its net rate per minute over the last 30s, green when rising and red when falling. |
| 2 | **Where does it go?** Hover a resource to see its producers and consumers | Factorio production stats | A tooltip on each item lists, for example, "Fiber: +12/min from 2 huts on flax, -18/min into Twine Post (makes Rope)". |
| 3 | **Click a building for its panel** | all four | Shows inputs and outputs as icons, the worker, the trip time, status, a pause toggle and a Demolish button. |
| 4 | **Demolish** | all four | Press X or use the panel button. You get 50% of the cost back, and its worker goes idle. The Camp can't be demolished. Demolish on a natural resource tile (forest, rocks, flax, berries, grain, gravel, clay) clears it to grass for good, free and with nothing back, so a hut can be steered or room made. The river, the Strange Stone, ore, unexplored land and the last tile of a kind stay. |
| 5 | **Pause and speed** | Timberborn, Anno | Space pauses. Keys 1, 2 and 3 set the speed to 1x, 2x and 3x, and buttons in the top-right corner do the same. |

## P2: A world with shape
| # | Convention | Seen in | Solace default |
|---|---|---|---|
| 6 | **Fog of war** | Civ, Anno | You start seeing 6 tiles around the Camp. Each building reveals 3 tiles, and Kith reveal 2 as they walk. Scouting adds +2 to both. Fog is drawn with the `fog` token. |
| 7 | **A settlement center** | Anno, Timberborn | The Camp is the Hearth. Kith are born there. Dwellings must be within 6 tiles of the Hearth, shown as a ring while you place one. Later eras add a second Hearth. |
| 8 | **Crossing water** | Timberborn | A Wooden Bridge unlocks with Paths & Haulers. It's placed on a river tile and costs 10 Wood and 2 Rope. Plain roads no longer cross rivers. Rafts stays a late shortcut. Anything cut off by water says so and points at the bridge. |
| 9 | **Placement previews** | all four | While placing, show the range, what a building will gather, trip time to the Hearth, and a road preview while dragging (hud.md). |

## P3: Expected comforts
| # | Convention | Seen in | Solace default |
|---|---|---|---|
| 10 | **Save and load** | all four | Autosave every 60s to user://, plus a Continue button on start. |
| 11 | **Alerts you can click** | Anno, Civ | Alerts like "Kiln starved" and "Kith starving" stack on the left. Click one to jump to it. |
| 12 | **Hotkeys** | all four | B opens build, T opens tech, X demolishes, Esc cancels, Space pauses. |
| 13 | **Pause a building or set its priority** | Timberborn | The building panel has a toggle. A paused building frees its worker. |

## Out of scope for now
Undo, blueprints, copy and paste of buildings, and a production graph over time. These come later, if players ask for them.
