extends Node3D

# The bullpen vending machine. A bag of PUFFY STARS is wedged against
# the glass - paid for, never collected. Shake the machine and it drops:
# you're holding the chips (`have_chips`, a per-loop holding). They're
# the counterweight for the evidence-room weight plate.
#
# First shove tells you what's stuck (`seen_stuck_snack`, permanent);
# from then on a shove dispenses. The machine itself never vanishes -
# only the wedged bag does, once you've dropped it THIS loop.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

@export var prompt_height := 1.7
## the wedged-bag mesh to hide once it drops (optional)
@export var bag_path: NodePath


func _ready() -> void:
	add_to_group("talkable")


func _process(_delta: float) -> void:
	# reflect the current loop's state: bag gone once dropped this loop
	var bag := get_node_or_null(bag_path)
	if bag != null:
		bag.visible = not Flags.has_loop_flag("have_chips")


func interact() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	if Flags.has_loop_flag("have_chips"):
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "Already got the bag. One's plenty."},
		])
		return
	if not Flags.has_flag("seen_stuck_snack"):
		# first look: learn what's hanging there (permanent knowledge)
		Flags.set_flag("seen_stuck_snack")
		dlg.show_dialogue([
			{"speaker": "VENDING MACHINE", "text": "A bag of PUFFY STARS hangs by one corner, wedged against the glass. Paid for. Never collected."},
			{"speaker": "DETECTIVE", "text": "Somebody wanted a snack in their last few minutes... and didn't stick around to shake it loose. A full bag - about a pound of air and salt."},
		])
		return
	# shake it loose - now you're holding it (resets every loop)
	Flags.set_loop_flag("have_chips")
	# the SMACK of a shoulder hitting the machine, then the mechanism
	# rattling the bag loose - CAPPED, the source recording runs for ages
	# and would still be droning from the next room over
	Sfx.play_at(self, "res://audio/sfx/bump.mp3", -6.0)
	Sfx.play_at(self, "res://audio/sfx/vending_machine.mp3", -8.0, 3.5)
	dlg.show_dialogue([
		{"speaker": "DETECTIVE", "text": "I put a shoulder into it. The bag drops. PUFFY STARS - mine now. Feels about right for a swap."},
	])
