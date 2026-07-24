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

@export var prompt_height := 1.4


func _ready() -> void:
	add_to_group("talkable")


func interact() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	if Flags.has_loop_flag("have_evidence_package"):
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Already made the swap. The package is mine this loop."},
		])
		return
	if Flags.has_loop_flag("have_chips"):
		# counterweight in hand - clean swap
		Flags.set_loop_flag("have_evidence_package")
		Flags.set_flag("found_murder_weapon")
		Flags.clear_loop_flag("have_chips")  # the chips stay on the plate
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Bag of Puffy Stars on the plate, package off. Even trade... A service revolver, serial filed off. Never logged. THIS is what killed the clerk."},
		])
	elif not Flags.has_flag("know_weight_trap"):
		# first look: learn the trap (permanent knowledge)
		Flags.set_flag("know_weight_trap")
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "A brown paper package, no tag, back on the plate. And the plate's spring-loaded - weight-sensitive. Lift it bare and every bell in the building goes off."},
			{"speaker": "DETECTIVE", "text": "I need something that weighs about the same to leave in its place. A full snack bag, maybe - about a pound."},
		])
	else:
		# knows the trap, no counterweight: a soft stop, NOT a loss - the
		# detective just won't do it without the swap ready
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Not without a counterweight. The second I lift this bare, the plate springs and the whole floor comes running. I need that snack bag first."},
		])
