# 33. Building keys

Status: **reference** (moved here from the head of `scripts/data/buildings.gd` on 2026-10-31, so that file stays under its line limit). What each key of a building in `Data.BUILDINGS` means. Add the key's line here when you add a key.

```text
kind: "camp" | "house" | "road" | "bridge" | "field" | "depot" | "gatherer" | "processor" | "power" | "aura" | "cairn"
  | "skyreach" (the Skyreach, built in stages from goods haulers bring; `sky_site`: only on the site a Signal Tower found)
  | "shed" (a Cart Shed) | "tower" (a Watchtower) | "wall" (the Glyph Wall)
  | "lantern" (the Shard Lantern) | "refuge" (the Lumen Camp, the shared shrine, the Guard Post) | "bench" (the Teardown Bench)
  | "barrel" (the Rain Barrel)
A building with an `event` (and no tech) opens when that story event has happened (Data.STORY_EVENTS): the era of the
Lumen has no research to gate it, and the card stays off the build bar until then.
A "field" with `crop` "flax" sows flax instead of grain (World.flax_fields); it yields fiber as wild flax does.
A `stone` bridge bears carts and walks at the top road tier; the Wooden Bridge bears the Kith only. A road has a
`tier` (0 path, 1 gravel, 2 paved, 3 rail; Data.ROAD_SPEEDS): dragging a higher tier over a lower one upgrades it in place for
the difference in cost, and the Stone Bridge does the same over a Wooden Bridge.
A processor with `trade` has no fixed recipe: it swaps Data.TRADE_GIVE of the good it is set to give for
Data.TRADE_GET of the one it is set to get (the building's `give` and `get`); a `trade_give` of its own replaces
Data.TRADE_GIVE (the Lumen Market gives 2). A trading building trades every good the people have held except its `trade_not`
list (the Trading Post: Kith goods, never a shard), or only the goods in its `trade_only` list (the Lumen Market: the Lumen's own
far-travelled goods). `sight` is how far a building sees.
`lesson` (a Data.LESSONS id) opens a building once that Lesson is learned (scripts/teardown.gd): the card stays off the bar
until then. `unique` allows one only. A `bench` has no worker: haulers carry parts to it (scripts/teardown.gd).
`story` buildings stay off the build bar until their tech is on the board and reachable (nothing to spoil early).
Processors turn `in` into `out` every `time` seconds (a processor with no `in` just makes `out`).
A processor with `makes` is a tool bench: a list of tool recipes (Data.RECIPES ids, worst first), and it makes
the best one the people have the tech and the stock for (the building's `make`), only while the stockpile holds
fewer tools than they need (Work.enough). Its own `in` and `out` stay empty.
A processor with `dig` is a mine: it stands on one of its `on_tiles` and digs `dig` of whatever that tile yields
each cycle, with no input and without walking. `crew` is how many people it needs (default 1); it works only
while all of them are at it.
A building with `fed` has no worker: haulers bring it its `in` (Data.RECIPES-style, up to `stock` of it) and it burns that on its
own (scripts/steam.gd): a "power" with a `fuel` burns `burn` seconds of it for each item and powers machines within `radius`
only while lit; a "lamp" lights `light` tiles; a "pen" eats Grain while it tames its beast. A "shed" with a `cart` ("hand" by
default, "steam") turns a hauler into that kind of cart (Data.CART_KINDS); a tamed Beast Pen gives a beast cart.
Buildings without a worker show `status`, or `desc` if they have none.
Livewire (page 23): a "pole" (the Power Pole) joins a net with the poles within Data.POLE_LINK tiles; a machine (`needs_power`) or
an engine (a "power" with `gives`, the units it adds to a net: Water Wheel 2, Boiler 3 while lit, Generator 8) within
Data.POLE_REACH tiles of a pole is on that net (scripts/power.gd). A "board" (the Order Board) holds the standing orders
(scripts/livewire.gd). A "power" with a `radius` of 0 reaches nothing of its own: it feeds a net or nothing.
```
