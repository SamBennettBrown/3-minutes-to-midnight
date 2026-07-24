extends Node3D

# The unlogged package deep in the stacks. The shelf plate under it is
# weight-sensitive: take it bare and the alarm ends the night. Swap in
# a full bag of chips from the bullpen vending machine and it's a clean
# lift. What you LEARN is forever; the package itself resets every loop.

const Flags := preload("res://scripts/game/flags.gd")

@export var prompt_height := 0.6


func _ready() -> void:
	add_to_group("talkable")


func _process(_delta: float) -> void:
	visible = not Flags.has_loop_flag("have_evidence_package")
	if not visible and is_in_group("talkable"):
		remove_from_group("talkable")
	elif visible and not is_in_group("talkable"):
		add_to_group("talkable")


func interact() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	if Flags.has_loop_flag("have_chips"):
		Flags.set_loop_flag("have_evidence_package")
		Flags.set_flag("found_murder_weapon")
		# the chips are spent making the swap - they don't leave with you
		Flags.clear_loop_flag("have_chips")
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Bag of Puffy Stars on the plate, package off. Even trade... A service revolver, serial filed off. Never logged. THIS is what killed the clerk."},
		])
	elif not Flags.has_flag("know_weight_trap"):
		Flags.set_flag("know_weight_trap")
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "A brown paper package, no tag. The shelf plate under it is spring-loaded - weight-sensitive. Lift it bare and every bell in the building knows."},
			{"speaker": "DETECTIVE", "text": "I need something that weighs about the same to leave in its place. A full snack bag, maybe - about a pound."},
		])
	else:
		# greedy and bare-handed: the alarm ends the night
		dlg.show_dialogue([
			{"speaker": "ALARM", "text": "The plate springs up. Bells. Boots in the hall. Wrong kind of famous."},
		])
		await dlg.closed
		var lose := get_tree().get_first_node_in_group("lose_screen")
		if lose != null:
			lose.play_lose()
