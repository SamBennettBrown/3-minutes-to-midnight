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
## the actual machine PROP that rocks on the shoulder-check. This script
## node only owns the interaction + collision; the visible machine is a
## separate prop, so rocking `self` moved nothing on screen.
@export var machine_path: NodePath


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
			{"speaker": "DETECTIVE", "text": "Already got loose bag, and one seems like plenty."},
		])
		return
	if not Flags.has_flag("seen_stuck_snack"):
		# first look: learn what's hanging there (permanent knowledge)
		Flags.set_flag("seen_stuck_snack")
		dlg.show_dialogue([
			{"speaker": "VENDING MACHINE", "text": "A bag of PUFFY STARS hangs by one corner, wedged against the glass. Paid for. Never collected."},
			{"speaker": "DETECTIVE", "text": "Looks like somebody wanted a snack... and didn't stick around to shake it loose. About A POUND of salty snacks. Let me see if I can reach it.."},
		])
		return
	# shake it loose - now you're holding it (resets every loop)
	Flags.set_loop_flag("have_chips")
	_drop_sequence()
	var journal := get_tree().get_first_node_in_group("journal")
	if journal != null:
		journal._show_toast("TAKEN  —  PUFFY STARS")
	dlg.show_dialogue([
		{"speaker": "DETECTIVE", "text": "I put a shoulder into it. The bag drops. PUFFY STARS - mine now. Feels about right for a swap."},
	])


# The full foley beat, in order: SMACK of the shoulder, then the mechanism
# rattling (capped - the source recording runs for ages), then the click of
# the bag landing in the tray. Timers run through the dialogue pause.
func _drop_sequence() -> void:
	Sfx.play_at(self, "res://audio/sfx/smack.mp3", -6.0)
	_rock()
	# the shoulder-check bumps the camera too - smaller than a gunshot
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.v_offset = 0.035
		var ct := create_tween()
		ct.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		ct.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		ct.tween_property(cam, "v_offset", 0.0, 0.3)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	Sfx.play_at(self, "res://audio/sfx/vendingmachine.mp3", -8.0, 3.5)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	Sfx.play_at(self, "res://audio/sfx/click.mp3", -8.0)


# the shoulder-check lands: the whole machine leans away, wobbles back
# past centre once, and settles. Runs through the dialogue pause.
func _rock() -> void:
	var target: Node3D = get_node_or_null(machine_path)
	if target == null:
		target = self
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(target, "rotation:z", 0.045, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "rotation:z", -0.022, 0.14).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "rotation:z", 0.01, 0.14).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "rotation:z", 0.0, 0.12).set_ease(Tween.EASE_OUT)
