extends Node3D

# A generic examinable object: evidence, notes, props. Stands in the
# world, shows the E prompt (same "talkable" group the NPCs use), runs
# its examine dialogue, and sets its story flag when the player
# finishes reading.
#
# Time-loop rule: you keep what you KNOW, not what you HOLD. There is
# no inventory - examining adds the fact to the case file (journal)
# via the flag. With `pickup` on, the object also vanishes once its
# flag is known (this loop and every loop after - you already have
# what it had to give).

const Flags := preload("res://scripts/game/flags.gd")

## examine text: [{"speaker": ..., "text": ...}]
@export var dialogue: Array = []
## story flag set when the examine dialogue finishes
@export var sets_flag := ""
## vanish once the flag is known
@export var pickup := false
## ON = this is a physical pickup you HOLD: its flag resets every loop
## (a keycard has to be re-stolen on the perfect run). OFF = knowledge,
## kept forever.
@export var per_loop := false
## where the E prompt floats, above this node's origin
@export var prompt_height := 0.5


func _ready() -> void:
	add_to_group("talkable")
	# only pickups need to watch for their flag - static examinables
	# never change, so they don't tick at all
	set_process(pickup and sets_flag != "")


func _flag_known() -> bool:
	return Flags.has_loop_flag(sets_flag) if per_loop else Flags.has_flag(sets_flag)


func _process(_delta: float) -> void:
	if visible and _flag_known():
		visible = false
		remove_from_group("talkable")
