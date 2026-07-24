extends Area3D

# A camera zone INSIDE a large room. Rooms bigger than one shot get
# 2-3 of these, each holding its own Camera3D child plus a trigger
# CollisionShape3D. Walking into a zone hard-cuts to its camera;
# visibility/neighbors stay owned by the parent Room, so this is purely
# "which angle films this part of the room."
#
# Authoring: under a Room node add CamZone (Area3D + this script) with
# a Camera3D child (position it, aiming is automatic) and a box
# CollisionShape3D covering that part of the room. Overlap neighboring
# zones slightly at the seam so walking back and forth re-cuts cleanly.

@export var camera_aim := false
@export var camera_look_at := Vector3(0, 1, 0)
@export var camera_dutch_deg := 0.0

var _camera: Camera3D


func zone_camera() -> Camera3D:
	return _camera


func _ready() -> void:
	for c in get_children():
		if c is Camera3D:
			_camera = c
			break
	if _camera != null and camera_aim:
		# look_at is LOCAL to the parent room, same as room.gd - authoring
		# stays correct when the room moves
		_camera.look_at_from_position(
				_camera.global_position, get_parent().to_global(camera_look_at))
		if camera_dutch_deg != 0.0:
			_camera.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(camera_dutch_deg))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and _camera != null:
		_camera.make_current()


const RoomState := preload("res://scripts/game/room.gd")


func _on_body_exited(body: Node3D) -> void:
	# stepped back into the room (not through the door): hand the shot
	# back to the room's main camera. NEVER steal the cut if another
	# room already took over - leaving through a door exits the zone
	# too, and re-activating here would yank the camera back.
	if not body.is_in_group("player"):
		return
	var room := get_parent()
	if RoomState.current != room:
		return
	var trig: Area3D = room.get_node_or_null("Trigger")
	if trig != null and trig.overlaps_body(body) and room.has_method("restore_main_camera"):
		room.restore_main_camera()
