@tool
extends "res://scripts/game/npc.gd"

# THE CAPTAIN - the killer. He runs the SAME routine every loop: escort the
# witness to the cells with the investigator, step back to the corridor, then
# walk off toward the LOCKER ROOM - and the instant he's inside it he VANISHES
# (he's "taken the hidden passage"; the passage is sealed to the player, so on
# a blind run he simply disappears and the witness dies in a sealed cell).
#
# Proving his guilt (cracking locker 0806 -> `captain_is_guilty`) does NOT
# change his route. It only unlocks the CATCH: the endgame_director lets you
# intercept him in the locker room during the 2:45-3:00 window, before he
# vanishes. Without proof, being there does nothing and he slips away as usual.
#
# Paced like the rest of the escort so he walks IN with the group; a long
# corridor idle-hold then delays his walk to the locker room so he only
# arrives there at the start of the intercept window (~2:45), not early.
# (Flags is inherited from player.gd via npc.gd.)

## loop time he vanishes into the passage (0 = never). The intercept window
## must close by here.
@export var vanish_into_passage_at := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint() and vanish_into_passage_at > 0.0:
		vanish_at = vanish_into_passage_at
	super._ready()
