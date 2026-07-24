extends Node3D

# Evidence intake closes near the end of the night: at kick_time the
# clerk boots the player out and the card gate stays shut for the rest
# of THIS loop (loop flag - it reopens when time resets).

const Flags := preload("res://scripts/game/flags.gd")
const RoomState := preload("res://scripts/game/room.gd")

@export var kick_time := 120.0
## where the player lands, just outside the gate (world)
@export var eject_to := Vector3(0, 0, -4.0)

var _clock: Node
var _done := false


func _process(_delta: float) -> void:
	if _done or get_tree().paused:
		return
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	if _clock.time < kick_time:
		return
	_done = true
	Flags.set_loop_flag("evidence_closed")
	var room := get_parent()
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p != null and room != null and room.has_method("contains_point") \
			and room.contains_point(p.global_position, 0.5):
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null and not dlg.visible:
			dlg.show_dialogue([
				{"speaker": "EVIDENCE CLERK", "text": "Intake's CLOSED, detective. Midnight rules. Out - now."},
			])
			await dlg.closed
		# the loop may have reset (clock/R) while that dialogue was open
		if is_instance_valid(p):
			p.global_position = eject_to
