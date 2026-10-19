extends RefCounted
## The play recorder (design-system/25-playtesting.md): the log's place and rhythm, the pause menu's switch, and the three
## questions asked after each era. Read through the `Data` facade (scripts/data.gd).

## Where the logs go: one JSON-lines file for each run, `<start>-seed<n>.jsonl`, under the game's user folder.
const PLAYLOG_DIR := "user://playlogs/"
## A sample of the town is written every this many game seconds.
const PLAYLOG_SAMPLE_SECONDS := 10.0

const PLAYLOG_LABEL := "Play log"
const PLAYLOG_HELP := (
	"Writes what you do and how long you wait to a file on this computer, so the game can be tuned to real play. "
	+ "Nothing is sent anywhere."
)

const ASK_TITLE := "How was that era?"
const ASK_SKIP := "Skip"
const ASK_DONE := "Done"
## Three taps, never typing: {id, text, options}. The answers go in the log's `era_end` line.
const ASK_QUESTIONS := [
	{"id": "feel", "text": "How did it feel?", "options": ["Dull", "Okay", "Good"]},
	{
		"id": "block",
		"text": "What got in your way most?",
		"options": ["Waiting for goods", "Not knowing what to do", "Too hard", "Nothing"]
	},
	{"id": "onward", "text": "Play on?", "options": ["Yes", "Not now", "I'm done"]},
]
