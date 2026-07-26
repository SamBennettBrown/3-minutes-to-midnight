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
const Sfx := preload("res://scripts/game/sfx.gd")

## loop time the clerk sets the card down (matches his desk-stop bark ~t25)
@export var drop_at := 26.0
## sound played the moment the card lands on the desk
@export_file("*.wav", "*.ogg", "*.mp3") var drop_sound := "res://audio/sfx/bump.mp3"
@export var drop_volume_db := -12.0
## sound played when you successfully palm it off the desk
@export_file("*.wav", "*.ogg", "*.mp3") var pickup_sound := "res://audio/sfx/click.mp3"
@export var pickup_volume_db := -8.0
## the loop flag the receptionist raises while she's turned away; taking
## the card is only safe when this is set
@export var safe_flag := "receptionist_turned"
## granted when you successfully lift the card (per-loop holding)
@export var grants_flag := "have_evidence_keycard"
@export var prompt_height := 0.3
## STORY LOCK - the card only exists once the opening monologue has handed
## over control (bound_promise). It stays hidden during the black-screen
## intro, then is available every loop after.
@export var unlock_flag := "bound_promise"
## the red pulse that marks the card as grabbable - base energy on the desk,
## and a brighter pulse while she's turned away (safe to lift)
@export var glow_color := Color(1.0, 0.15, 0.12)
@export var glow_energy := 2.2
@export var glow_energy_safe := 4.5

var _clock: Node
var _glow: OmniLight3D
var _pulse := 0.0
var _drop_played := false
var _prev_time := 999.0


func _ready() -> void:
	visible = false
	# a red marker light so the dropped card reads as "take me" against the
	# desk clutter (built in code so no scene wiring is needed)
	_glow = OmniLight3D.new()
	_glow.light_color = glow_color
	_glow.light_energy = 0.0
	_glow.omni_range = 1.2
	_glow.position = Vector3(0, 0.12, 0)
	add_child(_glow)


func _process(delta: float) -> void:
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
	# loop restarted (clock jumped back) - re-arm the drop sound
	if _clock.time < _prev_time - 1.0:
		_drop_played = false
	_prev_time = _clock.time
	# the CLINK the moment it lands on the desk (first appearance this loop)
	if show and not _drop_played:
		_drop_played = true
		if drop_sound != "" and ResourceLoader.exists(drop_sound):
			# positional - the clink belongs to the desk, not the whole station
			Sfx.play_at(self, drop_sound, drop_volume_db)
	if show != visible:
		visible = show
	# only offer the E-prompt while it's actually on the desk
	if show and not is_in_group("talkable"):
		add_to_group("talkable")
	elif not show and is_in_group("talkable"):
		remove_from_group("talkable")
	# pulse the red glow while it's grabbable; brighter while she's turned
	# away (the safe window) so the glow itself reads as "grab NOW"
	if show:
		_pulse += delta * 3.0
		var base: float = glow_energy_safe if Flags.has_loop_flag(safe_flag) else glow_energy
		_glow.light_energy = base * (0.7 + 0.3 * sin(_pulse))
	else:
		_glow.light_energy = 0.0


func interact() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	if Flags.has_loop_flag(safe_flag):
		# she's on the phone, turned away - clean lift
		Flags.set_loop_flag(grants_flag)
		# the KNOWLEDGE (card drops at 2:30, grab it during her calls) is
		# permanent - it becomes a timeline note in the case file
		Flags.set_flag("know_card_drop")
		if pickup_sound != "" and ResourceLoader.exists(pickup_sound):
			Sfx.play_at(self, pickup_sound, pickup_volume_db)
		var journal := get_tree().get_first_node_in_group("journal")
		if journal != null:
			journal._show_toast("TAKEN  —  EVIDENCE KEYCARD")
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
