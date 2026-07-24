extends Node3D

# The evidence-room keycard the clerk drops on the reception desk on his
# way out. It appears when he sets it down; after that it's grabbable -
# but ONLY while the receptionist is turned to the phone. Reach for it
# while she's watching and she simply blocks you - no harm, try again on
# her next call.
#
# What you HOLD resets every loop (`have_evidence_keycard` is a per-loop
# flag), so the perfect run has to re-steal it inside one of her calls.

const Flags := preload("res://scripts/game/flags.gd")

const StoryLock := preload("res://scripts/game/story_lock.gd")

## loop time the clerk sets the card down (matches his desk-stop bark ~t25)
@export var drop_at := 26.0
## the loop flag the receptionist raises while she's turned away; taking
## the card is only safe when this is set
@export var safe_flag := "receptionist_turned"
## granted when you successfully lift the card (per-loop holding)
@export var grants_flag := "have_evidence_keycard"
@export var prompt_height := 0.3
## STORY LOCK - the card only exists once you're a knowing looper. During
## loops 0-1 (the tutorial) it stays hidden/uninteractable, so you can't
## grab it before the game has taught you what it's for.
@export var unlock_flag := "know_loop"

var _clock: Node


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	# locked during the tutorial loops - not dropped, not there at all
	var unlocked: bool = StoryLock.is_unlocked(unlock_flag)
	# the card is on the desk from the moment the clerk drops it until you
	# take it this loop; taking it (have flag) hides it for the rest of
	# the loop, and a fresh loop clears the flag so it reappears on drop
	var dropped: bool = _clock.time >= drop_at
	var held: bool = Flags.has_loop_flag(grants_flag)
	var show: bool = unlocked and dropped and not held
	if show != visible:
		visible = show
	# only offer the E-prompt while it's actually on the desk
	if show and not is_in_group("talkable"):
		add_to_group("talkable")
	elif not show and is_in_group("talkable"):
		remove_from_group("talkable")


func interact() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	if Flags.has_loop_flag(safe_flag):
		# she's on the phone, turned away - clean lift
		Flags.set_loop_flag(grants_flag)
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Her back's turned. I palm the card off the desk edge. Evidence room's mine now - for a few minutes."},
		])
	else:
		# she's watching - she just blocks the grab. No harm; wait for her
		# to take a call and turn away, then try again
		dlg.show_dialogue([
			{"speaker": "RECEPTIONIST", "text": "Ah-ah. Hands off the desk, detective. That's not yours."},
			{"speaker": "DETECTIVE", "text": "...I'll wait until she's looking the other way."},
		])
