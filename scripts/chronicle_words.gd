extends RefCounted
## The words of the Chronicle (Step 7G, design-system/18-roadmap.md "The Chronicle as built"): the book that tells every telling of Solace,
## and what was chosen in each, in the voices of whoever was there. Placeholder words in the draft's voice, kept here apart from the
## code (scripts/chronicle.gd works the sky out, scripts/chronicle_book.gd draws it).
##
## A STAR is one choice point of a telling. Each of its options has the story id the telling recorded (`event`, "" for the road
## with no id), the `entry` its own voice writes when it was taken, and the `whisper` somebody says of it when the other road was
## taken, so an option never taken is wondered about and never drawn as a faint star. From the third telling on the Bloom adds a
## broken fragment to every star (BLOOM_FROM, `bloom`).

const VOICES := {
	"elder": "The Hearthkeeper",
	"sela": "Sela",
	"lumen": "A Lumen mender",
	"bloom": "The Bloom",
}
const BLOOM_FROM := 3  # the telling from which the Bloom's fragments show

# The choice points of a telling, in the order they are asked.
const STAR_ORDER := ["cairn", "hunger", "shards", "warning", "lean", "ending"]
const STARS := {
	"cairn":
	{
		"name": "The Cairn",
		"question": "A cairn of shards, before anyone asked?",
		"bloom": "...stones... a hand set them... I was the hand...",
		"options":
		{
			"raised":
			{
				"event": "cairn_raised",
				"label": "Raised a cairn",
				"entry":
				{
					"voice": "elder",
					"text": "We raised a cairn of shards. It gave the strangers somewhere to walk toward."
				},
				"whisper":
				{
					"voice": "elder",
					"text": "I still think of the cairn we might have raised. Stones can say come when mouths cannot."
				},
			},
			"unraised":
			{
				"event": "",
				"label": "No cairn",
				"entry": {"voice": "elder", "text": "We raised no cairn. The strangers found the fire without one."},
				"whisper":
				{
					"voice": "elder",
					"text": "Some nights I wonder what we would have kept, had we left the stones where they lay."
				},
			},
		},
	},
	"hunger":
	{
		"name": "The Hunger",
		"question": "Food, when the strangers were thin?",
		"bloom": "...bread... the field was mine... who was hungry...",
		"options":
		{
			"shared":
			{
				"event": "hunger_shared",
				"label": "Shared the food",
				"entry":
				{
					"voice": "sela",
					"text": "You shared your food when your own children were thin. I did not forget it."
				},
				"whisper": {"voice": "sela", "text": "I still wonder what would have happened if you had shared."},
			},
			"held":
			{
				"event": "hunger_held",
				"label": "Kept the food",
				"entry":
				{
					"voice": "sela",
					"text": "You kept your food. I understood. I also remembered, and so did the ones who went hungry."
				},
				"whisper":
				{
					"voice": "sela",
					"text": "Sometimes I think the Kith were wiser than we thought, to keep their bread."
				},
			},
		},
	},
	"shards":
	{
		"name": "The Shards",
		"question": "The Strange Stone, when the strangers asked?",
		"bloom": "...they glow... I keep what glows... I kept...",
		"options":
		{
			"given":
			{
				"event": "shards_given",
				"label": "Gave the shards",
				"entry":
				{
					"voice": "lumen",
					"text": "They gave us the shards, all of them. We did not know what to do with so much trust."
				},
				"whisper":
				{
					"voice": "lumen",
					"text": "A world where they simply handed us the shards. I cannot picture it, and I keep trying."
				},
			},
			"traded":
			{
				"event": "shards_traded",
				"label": "Traded a shard",
				"entry":
				{
					"voice": "lumen",
					"text":
					"They asked for a favour in return, one shard for one. It was the fairest bargain I had seen here."
				},
				"whisper": {"voice": "lumen", "text": "Perhaps a fair trade would have been enough for everyone."},
			},
			"refused":
			{
				"event": "shards_refused",
				"label": "Refused the shards",
				"entry":
				{
					"voice": "lumen",
					"text":
					"They would not part with the Strange Stone. I do not blame them. It was theirs before we were."
				},
				"whisper":
				{"voice": "lumen", "text": "Had they kept the shards, we would have had to learn how to ask."},
			},
		},
	},
	"warning":
	{
		"name": "The Warning",
		"question": "Dark, when the strangers asked for it?",
		"bloom": "...dark is only waiting... I waited...",
		"options":
		{
			"kept":
			{
				"event": "dark_kept",
				"label": "Went dark",
				"entry":
				{
					"voice": "sela",
					"text":
					"I asked the Kith to go dark, and they did. A whole town hid from a thing it could not see, because I asked."
				},
				"whisper": {"voice": "sela", "text": "I wonder if the light would have been seen, and by whom."},
			},
			"refused":
			{
				"event": "dark_refused",
				"label": "Kept the fires lit",
				"entry":
				{
					"voice": "sela",
					"text": "I asked them to put out their fires. They kept them lit, and the light carried a long way."
				},
				"whisper": {"voice": "sela", "text": "I wonder what the dark would have shown us."},
			},
		},
	},
	"lean":
	{
		"name": "The Lean",
		"question": "How the Lumen and the Kith ended?",
		"bloom": "...two fires, one root... I had one root...",
		"options":
		{
			"allies":
			{
				"event": "lean_allies",
				"label": "Allies",
				"entry":
				{
					"voice": "elder",
					"text": "By the end the Lumen and the Kith shared a fire, and stopped counting whose it was."
				},
				"whisper":
				{"voice": "elder", "text": "I wonder what it is to have friends who need no road between you."},
			},
			"neighbours":
			{
				"event": "lean_neighbours",
				"label": "Neighbours",
				"entry":
				{
					"voice": "elder",
					"text": "The Lumen kept their camp and we kept ours, and the road between them was well walked."
				},
				"whisper":
				{"voice": "elder", "text": "A road well walked is a kind of peace. I wonder if it is enough."},
			},
			"enemies":
			{
				"event": "lean_enemies",
				"label": "Enemies",
				"entry":
				{"voice": "elder", "text": "We watched each other across the fields, and neither side slept well."},
				"whisper":
				{"voice": "elder", "text": "I do not like to think of the telling where we never learned to trust."},
			},
		},
	},
	"ending":
	{
		"name": "The Ending",
		"question": "How the telling ended?",
		"bloom": "...a river... I was a river once...",
		"options":
		{
			"exodus":
			{
				"event": "ending_exodus",
				"label": "Exodus",
				"entry":
				{
					"voice": "elder",
					"text": "We left the town standing, lamps lit, and walked out into a land we had not seen."
				},
				"whisper": {"voice": "elder", "text": "I still dream of the town we left behind, lit and empty."},
			},
			"cataclysm":
			{
				"event": "ending_cataclysm",
				"label": "Cataclysm",
				"entry":
				{
					"voice": "elder",
					"text":
					"The light broke the sky. We woke in our own ruins, and something green was already growing in them."
				},
				"whisper":
				{"voice": "elder", "text": "I wonder if the ruins would have been kinder, had we left them to rest."},
			},
			"loop":
			{
				"event": "ending_loop",
				"label": "Time loop",
				"entry": {"voice": "elder", "text": "The planet turned back on itself. Only we remembered."},
				"whisper":
				{
					"voice": "elder",
					"text": "A second chance for everyone. I wonder what it costs the ones who do not know."
				},
			},
		},
	},
}

# Embers: hidden moments that light a small star the first time a telling shows them. Nothing says what they are until they are lit.
const EMBERS := {
	"open_hands":
	{
		"name": "Open hands",
		"voice": "sela",
		"text": "Food shared, shards given, the dark kept for us. I have not met another people who gave so much.",
	},
	"closed_doors":
	{
		"name": "Closed doors",
		"voice": "sela",
		"text":
		"Bread kept, shards refused, fires lit against the warning. I have not met another people so sure of themselves.",
	},
	"cairn_first":
	{
		"name": "A cairn before the star",
		"voice": "elder",
		"text": "We raised the stones before the star came down. Perhaps something in us already knew.",
	},
	"lone_fire":
	{
		"name": "Friends without a cairn",
		"voice": "lumen",
		"text": "No stones to guide us, and still we sat at one fire. That is rarer than it should be.",
	},
	"ship_found":
	{
		"name": "The ship under the roots",
		"voice": "elder",
		"text": "Under the moss lay the ribs of a hull older than the oldest story. We went home quiet.",
	},
	"three_gifts":
	{
		"name": "Three gifts from the ruins",
		"voice": "elder",
		"text":
		"The forge, the lantern and the cart, all dug out in one telling. The old town gave back what it could.",
	},
	"whole_word":
	{
		"name": "The whole word",
		"voice": "lumen",
		"text": "Every set of marks, read. I did not think the Kith would ever hear the whole of it.",
	},
}
const EMBER_ORDER := [
	"open_hands", "closed_doors", "cairn_first", "lone_fire", "ship_found", "three_gifts", "whole_word"
]

# The sequences the book can show again (Data.CUTSCENES), each with the name it is listed under.
const SCENES := {
	"opening": "The first fire",
	"next_telling": "The next land",
	"bronze_dawn": "Bronze Dawn",
	"falling_star": "The falling star",
	"first_contact": "The strangers",
	"starfall_end": "The end of the Starfall",
	"ironfall": "Ironfall",
	"bloom_sign": "The first sign",
	"skyward_end": "The mast",
	"kin_reveal": "The ship before ours",
	"broken_world": "The broken world",
	"way_out": "The door",
	"fireside": "The fireside",
}

# Lore, in four layers; a layer opens when the story id has happened in any telling.
const LAYERS := [
	{
		"title": "The strangers",
		"event": "name_read",
		"text":
		"Three strangers came out of the fog. They are the Lumen, and they carry a ship's worth of marks and a star's worth of grief.",
	},
	{
		"title": "The Kin",
		"event": "ship_read",
		"text":
		"The ship that fell before ours was full of children. The Kith learned they were Kin of the Lumen, who came home and did not know it.",
	},
	{
		"title": "The broken world",
		"event": "broke_read",
		"text":
		"This world was shaped too hard, by hands that loved it. The Bloom is what the shaping left, and it remembers being a river.",
	},
	{
		"title": "The way out",
		"event": "way_read",
		"text":
		"There is a door the first ship could not use. It needs everyone it has ever carried. Shut it, heal what is outside it, or go.",
	},
]
const LAYER_LOCKED := "Not yet read."

# The people.
const PEOPLE := {
	"elder":
	{
		"name": "The Hearthkeeper",
		"portrait": "portrait_kin_elder",
		"text":
		"Keeper of the Kith's fire and of the telling. Each time the Kith begin again, the Hearthkeeper tells the children what was.",
	},
	"sela":
	{
		"name": "Sela",
		"portrait": "portrait_sela",
		"text":
		"Sela leads the Lumen. She asks, and waits, and remembers. How far she trusted the Kith, telling by telling:",
	},
	"bloom":
	{
		"name": "The Bloom",
		"portrait": "portrait_bloom",
		"text": "A growth at the edge of the fog. It does not speak, yet.",
		"text_later":
		"A growth that was once a world's whole river. Its fragments surface, broken, in the tellings it has seen.",
	},
}
const SELA_TRUST := "Telling %d: %s (%d trust)"

# The endings page: the three that are open now, and the three true endings that Step 8 builds.
const ENDINGS_TIMES := "%d time"
const TRUE_ENDINGS := [
	{
		"name": "Seal Solace",
		"line": "Shut the door, and keep the world as it is.",
		"needs": "Read The Way Out while the Lumen are allies.",
	},
	{
		"name": "Heal the Bloom",
		"line": "Mend what the first hands broke.",
		"needs": "Read The Way Out while the Lumen are allies, after an earlier Cataclysm.",
	},
	{
		"name": "Leave together",
		"line": "Go through the door, with everyone it has carried.",
		"needs": "Read The Way Out while the Lumen are allies, after an earlier Time loop.",
	},
]

# The book itself.
const TITLE := "The Chronicle"
const SUBTITLE := "Every telling of Solace, and what you chose in each."
const TABS := ["Tellings", "Lore", "People", "Endings"]
const EMPTY_SKY := "The sky is empty. Your first telling is still being told. When it ends, its stars appear here."
const OPEN_TELLING := "Telling %d"
const NUMBERS := "%d minutes · %d Kith · %d buildings · %d taken by the Bloom"
const EMBERS_FOUND := "Embers lit: %d"
const WATCH := "Watch"
const BACK := "Close"
const BEGIN := "Begin the next telling"
const SCENES_TITLE := "Scenes"
const DICTIONARY_TITLE := "The marks"
const MARK_UNREAD := "?"
const ENDINGS_OPEN := "Endings reached"
const ENDINGS_TRUE := "True endings"
const NEVER := "not yet"
