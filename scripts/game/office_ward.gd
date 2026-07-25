extends Area3D

# The captain guarding his office. While he's still here (before he leaves
# for the locker room at `clear_at`), being ANYWHERE in the office gets you
# his brush-off and a shove out into the bullpen. No restart, no death.
# After he leaves, the office is yours.
#
# This POLLS the office room's floor footprint every frame instead of using
# an Area box - a box left uncovered strips along the walls that you could
# sneak through. The floor footprint IS the room; there is nowhere to hide.
# (The node stays an Area3D only so the scene doesn't need restructuring.)
#
# The shove destination must sit WELL inside the bullpen floor - a
# destination on the doorway seam makes the room resolver flip-flop.

const Flags := preload("res://scripts/game/flags.gd")

## loop time the captain leaves (office becomes free afterward). Match the
## captain's schedule departure.
@export var clear_at := 120.0
## where he shoves you back to (world) - well inside the bullpen
@export var shove_to := Vector3(-7.5, 0, -3.6)
## how deep past the doorway counts as "inside" (shrinks the floor test so
## brushing the door frame doesn't trigger)
@export var entry_grace := 0.4
@export var line := "I'm busy, detective. This isn't a break room. Out."
@export var speaker := "THE CAPTAIN"

var _clock: Node
var _room: Node3D
var _said_this_loop := false
var _cooldown := 0.0
var _prev_time := 999.0


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	# loop restarted (clock jumped back): re-arm the line + shove
	if _clock.time < _prev_time - 1.0:
		_said_this_loop = false
		_cooldown = 0.0
	_prev_time = _clock.time
	# once he's gone, the office is open
	if _clock.time >= clear_at:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	if _room == null:
		_room = _find_office()
		if _room == null:
			return
	if _cooldown > 0.0:
		return
	# the whole room is his: floor footprint, shrunk a hair at the doorway
	if _room.contains_floor_point(p.global_position, -entry_grace):
		_cooldown = 1.0
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null and not dlg.visible and not _said_this_loop:
			_said_this_loop = true
			dlg.show_dialogue([{"speaker": speaker, "text": line}])
		p.set_deferred("global_position", shove_to)


func _find_office() -> Node3D:
	# the room this ward lives in (walk up), else by name
	var n: Node = get_parent()
	while n != null:
		if n.is_in_group("room"):
			return n as Node3D
		n = n.get_parent()
	for r in get_tree().get_nodes_in_group("room"):
		if String(r.name) == "CaptainsOffice":
			return r as Node3D
	return null
