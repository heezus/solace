extends RefCounted
## The Lumen tab and the buildings it opens (design-system/16-starfall.md, "Stage 5 as built"): reading a glyph set opens one
## building, and what the gifts once did round the Cairn now lives in that building. Read through the `Data` facade
## (scripts/data.gd) as `Data.LUMEN`, one dictionary so the facade stays small.

const LUMEN := {
	# The tech panel's tab.
	"tab": "Lumen",
	"tab_tip": "What the Lumen taught: each set of marks you read opens a building",
	"tab_locked": "Opens when the strangers arrive",
	"title": "The Lumen's teaching",
	"explain": "Each set of marks you read opens one Lumen building. Build it and what the Lumen taught goes to work.",
	"closed": "Read the %s marks to open this",
	"build_on": "Build it on the %s tab.",
	"standing": "%d standing",
	"none_standing": "None standing yet",
	"own_way":
	{
		"growth": "The Kith planted their own way to grow it, so the Grove is open anyway.",
		"craft": "The Kith found their own way to bind shard, so the Shardwright is open anyway.",
	},
	# The four cards, in the order of Data.ROAD_ORDER: the set that opens it, the building, the build bar tab and what it does.
	"cards":
	{
		"light":
		{
			"set": "Light",
			"building": "shard_lantern",
			"tab": "Lore",
			"does":
			"Shardlight 4 tiles round. Gatherers in it work 25% faster, and the Grove and the Shardwright can work in it.",
		},
		"body":
		{
			"set": "Body",
			"building": "healing_house",
			"tab": "Homes",
			"does": "One Kith, a Mender. Homes within 6 tiles have births 20% sooner and their tools last 40% longer.",
		},
		"growth":
		{
			"set": "Growth",
			"building": "starfruit_grove",
			"tab": "Gathering",
			"does": "One Kith grows Starfruit, a food worth two berries. It grows only in shardlight.",
		},
		"craft":
		{
			"set": "Craft",
			"building": "shardwright",
			"tab": "Workshops",
			"does":
			"One Kith binds Rope and Bronze into Shardwork. It works only in shardlight, and workshops in its light work 25% faster.",
		},
	},
	# What a building says while it works or waits.
	"needs_light": "Needs shardlight",
	"needs_light_status":
	"Needs shardlight: build a Shard Lantern within %d tiles, or stand within %d tiles of the Cairn",
	"mending": "Mending: homes within %d tiles have births sooner and their tools last longer",
	"mender_radius": 6.0,
	# The Lumen Ward (Lore tab, opens with the Craft set): the strangers will not speak the Warning until one stands.
	"ward_trust": 10.0,
	"ward_built":
	"The strangers step inside the Ward and the shardlight holds. For the first time they look as if they might sleep.",
	"ward_word": ["not built", "built"],
	"ward_row": "The Lumen Ward: %s. The strangers will not speak the Warning until it stands.",
}
