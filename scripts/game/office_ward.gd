extends Area3D

# The captain's office while he's inside: the DOOR IS SIMPLY BLOCKED.
# Bump it and he growls through the wood - no shove, no teleport, no
# control-scheme weirdness (the old teleport ate tank-control state and
# could be snuck past). At `clear_at` he's gone and the office is open.
#
# The solid slab is built in code and parked across the doorway, so the
# scene needs no restructuring - this node just has to live in the office.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

## loop time the captain leaves (the door unblocks). Match his schedule.
@export var clear_at := 120.0
## the door gap, in OFFICE-LOCAL coords (south wall doorway)
@export var door_local := Vector3(2.5, 1.5, 4.97)
@export var door_size := Vector3(2.4, 3.0, 0.35)
@export var line := "Occupied. I'm in here, detective - find somewhere else to be."
@export var speaker := "THE CAPTAIN"

var _clock: Node
var _room: Node3D
var _shape: CollisionShape3D
var _said := false


func _ready() -> void:
	_room = _find_office()
	var block := StaticBody3D.new()
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = door_size
	_shape.shape = box
	block.add_child(_shape)
	add_child(block)
	# the office room sits unrotated in the world, so local offsets add
	if _room != null:
		block.global_position = _room.global_position + door_local
	else:
		block.position = door_local


func _process(_delta: float) -> void:
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	var closed: bool = _clock.time < clear_at
	if _shape.disabled == closed:
		_shape.disabled = not closed
	if not closed or _said:
		return
	# bump line, once per loop (scene reload re-arms it) - HORIZONTAL
	# distance; the slab centre sits 1.5m up
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var flat := (_room.global_position + door_local) - p.global_position if _room != null \
			else global_position - p.global_position
	flat.y = 0.0
	if flat.length() < 1.7:
		_said = true
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null and not dlg.visible:
			dlg.show_dialogue([{"speaker": speaker, "text": line}])


func _find_office() -> Node3D:
	var n: Node = get_parent()
	while n != null:
		if n.is_in_group("room"):
			return n as Node3D
		n = n.get_parent()
	for r in get_tree().get_nodes_in_group("room"):
		if String(r.name) == "CaptainsOffice":
			return r as Node3D
	return null
