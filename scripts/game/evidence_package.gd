extends Node3D

# The evidence shelf holding the unlogged package, deep in the stacks and
# blocked by the sliding shelf in front of it. The plate under the package
# is weight-sensitive: you can't lift it bare - without a counterweight
# (a full bag of chips from the bullpen vending machine) the detective
# just won't risk it. It's a soft stop, a popup, NOT a loss. What you
# LEARN is forever; the package holding resets every loop.
#
# This script rides the shelf itself, so it never hides the shelf - only
# the "have_evidence_package" holding tracks whether you've taken it.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

@export var prompt_height := 1.4
## the sound of the counterweight swap - chips down, package up
@export_file("*.wav", "*.ogg", "*.mp3") var pickup_sound := "res://audio/sfx/pickup.mp3"
@export var pickup_volume_db := -8.0
## the sliding shelf parked in FRONT of this one - until it's been shoved
## aside, you can't reach past it to the plate
@export var blocker_path: NodePath


func _ready() -> void:
	add_to_group("talkable")


func interact() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	# the slider in front must be OUT before you can reach the back shelf
	var blocker := get_node_or_null(blocker_path)
	if blocker != null and not bool(blocker.get("_out")):
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "There's a whole shelf parked flush in front of this one. I can't reach past it - it'll have to move first."},
		])
		return
	if Flags.has_loop_flag("have_evidence_package"):
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Already made the swap. The package is mine this loop."},
		])
		return
	if Flags.has_loop_flag("have_chips") and Flags.has_flag("know_weight_trap"):
		# trap known AND counterweight in hand THIS loop - clean swap.
		# (both gates matter: without know_weight_trap the first-look plays
		# below, so the swap can never fire before the setup)
		Flags.set_loop_flag("have_evidence_package")
		Flags.set_flag("found_murder_weapon")
		Flags.clear_loop_flag("have_chips")  # the chips stay on the plate
		if pickup_sound != "" and ResourceLoader.exists(pickup_sound):
			Sfx.play_at(self, pickup_sound, pickup_volume_db)
		var journal := get_tree().get_first_node_in_group("journal")
		if journal != null:
			journal._show_toast("TAKEN  —  THE PACKAGE")
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Bag of Puffy Stars on the plate, package off. Even trade... It's not a weapon. It's a case file. The one the witness is testifying against."},
			{"speaker": "DETECTIVE", "text": "A mugshot clipped to the front. And behind it - a family photo. Two brothers at a lake, arms around each other. One of them is our defendant."},
			{"speaker": "DETECTIVE", "text": "The other... is the CAPTAIN. The man the witness would put away is his own brother. THAT'S the motive. Somebody buried this here to keep it quiet."},
			{"speaker": "DETECTIVE", "text": "If the Captain's the shooter... maybe I can get to his gun first. Crack his locker, take the piece, and prevent this whole thing once and for all."},
		])
	elif not Flags.has_flag("know_weight_trap"):
		# first look: learn the trap (permanent knowledge)
		Flags.set_flag("know_weight_trap")
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "A brown paper package - no tag, no log number, tucked behind the shelf on a spring-loaded plate. Filed evidence doesn't live like this. Somebody in this building BURIED it."},
			{"speaker": "DETECTIVE", "text": "And the plate's weight-sensitive - lift it bare and every bell rings. I need a stand-in. About a POUND."},
		])
	else:
		# knows the trap, no counterweight: a soft stop, NOT a loss - the
		# detective just won't do it without the swap ready
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Not without a counterweight. The second I lift this, the plate springs and the whole floor comes running. I'll have to do this... Indiana Jones style."},
		])
