extends Area3D

# The precinct's front door. Walking into it ends the night: on loop 0
# it IS the tutorial goal (clock out, go home - the shot rings out just
# as you reach the door), and on every loop after, the promise in your
# pocket simply won't let you leave.

const Flags := preload("res://scripts/game/flags.gd")

var _fired := false


func _ready() -> void:
	body_entered.connect(_on_enter)


func _on_enter(body: Node3D) -> void:
	if _fired or not body.is_in_group("player"):
		return
	_fired = true
	if not Flags.has_flag("intro_done"):
		var d := get_tree().get_first_node_in_group("intro_director")
		if d != null:
			d.clock_out()
		return
	# post-intro: leaving is just another way the night ends
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null:
		dlg.show_dialogue([{"speaker": "DETECTIVE",
				"text": "The trinket burns cold in my pocket. I can't leave. Not until he makes it through this night."}])
		await dlg.closed
		# the loop may have reset while the refusal line was on screen
		if not is_inside_tree():
			return
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		lose.play_lose()
