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
| Gather from a tile | Hold the left button on it: a ring fills, then the harvest pops (keep holding to repeat) |
| Send a hut's Kith out for a bundle | Left-click the hut (up to 3 trips queue, shown as pips) |
| Collect from / load a building with no road | Left-click the building |
| Rush a working building | Left-click it (then a 5 s cooldown) |
| Lay roads | Pick Road, then click or drag |
| Place a building | Pick it in the bottom bar, then left-click open grassland |
| Stop placing | Right-click or Esc |
| Tech tree | T, or the button in the bottom bar |
| Craft | Craft buttons in the bottom bar |

## How the loop works
- Follow the **Goals** panel on the right. The **Info** panel explains whatever you point at.
- Gather by hand at first. Harvest a resource 10 times and a watching Kith learns it: its Gatherer's Hut then works it.
  Knapping lets you craft Flint Tools, which shorten the hold. A harvest yields base x tool x rank, and ranks II and III
  on a tech's card raise it further.
- The **Kith** are your people, and each one is on the map. Every building needs one Kith to work it.
  They eat food (berries, or flour at 3x value). They grow when there is spare food and room: the Camp houses 4, each **Dwelling** 3. If the food runs out, they stop working, and after a while one leaves.
- A **Gatherer's Hut** sends its worker out to the resource tiles within 2 tiles and back, so a hut surrounded by resources is faster.
- Fiber comes from **wild flax**, never bare grass. There is always a patch near the Camp.
- **Paths & Haulers** turns idle Kith into haulers. They serve only buildings a **Road** links to the Camp or a **Storehouse**, and walk the roads only. A linked hut loops on its own; an unlinked one shows "Needs road" and still needs clicks.
- **Roads** (2 Wood a tile) double walking speed. They fell forest, cut passes through rocks for 3 Stone, and a road across the river is a bridge. Click or drag to lay them.
- Flour that research still needs is never eaten.
- The **Water Wheel** must touch the river and powers machines within 3 tiles. The **Grindstone** needs power.
- Research **Bronze Dawn** to end the stone age.
- Somewhere on the map is a strange, glowing stone.

## Project layout
| Path | What it is |
|---|---|
| `scripts/data.gd` | The `Data` facade: `Data.X` reads a constant from the domain file that defines it. |
| `scripts/data/` | The data, by domain: items, people, tiles, techs, buildings, goals and tuning. Tune the game here. |
| `scripts/sim.gd` | `Sim`, the simulation (no rendering, so it runs headless in tests): a thin owner of one of each block (`economy`, `world`, `pathing`, `tech_tree`, `town`, `people`, `story`, `fog`) and the tick order. |
| `scripts/main.gd` | Vector drawing (Advance Wars style) and UI, built in code. |
| `scripts/art.gd` | Static drawing helpers: map features, building shapes, tech-tree arrows. |
| `scenes/main.tscn` | The single scene. |
| `tests/run_tests.gd` | Headless logic tests. |

## Tests
```sh
godot --headless --path . -s tests/run_tests.gd
```
CI runs the linter, loads the main scene, and runs these tests on every push.

## Design system
The canon for Solace's world (lore, factions, art direction, decisions) lives in the project's design system, and this repo follows it.
