extends RefCounted
## The words of the title screen and the pause menu (scripts/title_screen.gd, scripts/pause_menu.gd). Read through the
## `Data` facade (scripts/data.gd).

const TITLE_NAME := "Solace"
const TITLE_TAGLINE := "Guide the Kith from stone tools to the stars."
const TITLE_WHISPER := "Three peoples. One planet."  # a hint, not a promise, of the factions in the art
const TITLE_NEW := "New game"
const TITLE_CONTINUE := "Continue"
const TITLE_NO_SAVE := "No saved game yet"
const TITLE_QUIT := "Quit"
const TITLE_BAD_SAVE := "That save could not be read. A new game was started."

const PAUSE_TITLE := "Paused"
const PAUSE_RESUME := "Resume"
const PAUSE_SAVE := "Save game"
const PAUSE_LOAD := "Load game"
const PAUSE_QUIT := "Quit to title"
const PAUSE_HINT := "Esc to resume. Quitting to the title loses anything not saved."
const SAVE_DONE := "Game saved."
const SAVE_FAILED := "The game could not be saved."
const LOAD_NONE := "There is no saved game to load."
