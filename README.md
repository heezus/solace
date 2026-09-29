# Solace

Guide the Kith from stone tools to super-advanced industry on the planet Solace, until a fallen star brings magic, rivals, and the thing that hunted them.

This is the **first playable**: the stone age loop with a lite tech tree, ending at the Bronze Dawn era gate.

## Play it
1. Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).
2. Clone this repo.
3. In the Godot Project Manager, click **Import**, pick `project.godot`, then press **F5** (or the ▶ button).

## Controls
| Action | Input |
|---|---|
| Gather from a tile | Left-click it |
| Collect from / load a building (before haulers) | Left-click the building |
| Place a building | Pick it in the bottom bar, then left-click open grassland |
| Stop placing | Right-click or Esc |
| Tech tree | T, or the button in the bottom bar |
| Craft | Craft buttons in the bottom bar |

## How the loop works
- Click resources by hand at first. Knapping lets you craft Flint Tools, which doubles hand gathering.
- A **Gatherer's Hut** is your first self-running building. It gathers from resource tiles within 2 tiles, and fills up until you click to collect.
- **Paths & Haulers** makes every building feed and empty itself automatically. That's when the machine runs on its own.
- Running buildings eat food (berries, or flour at 3x value). No food means they stop.
- The **Water Wheel** must touch the river and powers machines within 3 tiles. The **Grindstone** needs power.
- Research **Bronze Dawn** to end the stone age.
- Somewhere on the map is a strange, glowing stone.

## Project layout
| Path | What it is |
|---|---|
| `scripts/data.gd` | All items, tiles, techs, recipes and buildings. Tune the game here. |
| `scripts/game_state.gd` | The simulation (no rendering), so it can be tested headless. |
| `scripts/main.gd` | Vector drawing (Advance Wars style) and UI, built in code. |
| `scenes/main.tscn` | The single scene. |
| `tests/run_tests.gd` | Headless logic tests. |

## Tests
```sh
godot --headless --path . -s tests/run_tests.gd
```
CI runs the linter, loads the main scene, and runs these tests on every push.

## Design system
The canon for Solace's world (lore, factions, art direction, decisions) lives in the project's design system, and this repo follows it.
