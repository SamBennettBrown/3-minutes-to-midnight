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
const StoryLock := preload("res://scripts/game/story_lock.gd")

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
## STORY LOCK: leave empty for "always available". Set a flag (e.g.
## "bound_promise") and this stays hidden/uninteractable until that flag is
## set - so nothing is exposed during the black-screen opening.
@export var unlock_flag := ""
## optional sound on EVERY examine - the metal clank of a locker being
## pulled open. Empty = silent (notes, photos).
@export_file("*.wav", "*.ogg", "*.mp3") var examine_sound := ""


func _ready() -> void:
	add_to_group("talkable")
	# tick if it's a pickup that can vanish, OR if it's story-locked (needs
	# to watch for the unlock). Static, always-available examinables never
	# change, so they don't tick at all.
	set_process((pickup and sets_flag != "") or unlock_flag != "")
	if unlock_flag != "":
		_apply_lock()


func _flag_known() -> bool:
	return Flags.has_loop_flag(sets_flag) if per_loop else Flags.has_flag(sets_flag)


func _process(_delta: float) -> void:
	# story lock: appear only once unlocked (and re-hide if somehow relocked)
	if unlock_flag != "":
		_apply_lock()
		if not visible:
			return
	if visible and _flag_known():
		visible = false
		remove_from_group("talkable")


func _apply_lock() -> void:
	var open := StoryLock.is_unlocked(unlock_flag)
	if open and not visible and not _flag_known():
		visible = true
		if not is_in_group("talkable"):
			add_to_group("talkable")
	elif not open:
		if visible:
			visible = false
		if is_in_group("talkable"):
			remove_from_group("talkable")
