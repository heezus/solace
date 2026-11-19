extends RefCounted
## When the AI player's table keeps its era save (tests/tools/ai_player.gd): on its first page and on the first page of every new era.
## Fun playtest 7: era_save.json stayed at the Stone Age through a whole run, because the table noted the new era before it looked
## for the change. `due` notes the era only when it says a save is due.

var kept := ""  # the era of the last save, "" before the first


## True when page `n` should save the game: it is the first page (`first`) or `era` is not the era of the last save.
func due(n: int, first: int, era: String) -> bool:
	if n != first and era == kept:
		return false
	kept = era
	return true
