extends Node3D

# One room: geometry + one fixed camera + a Trigger (Area3D) volume.
# When the player walks into the trigger, this room's camera hard-cuts
# live and every other room in the "room" group is hidden.
#
# Template usage: duplicate a Room node, move it, reshape its walls and
# Trigger box, place its Camera3D. That's the whole pipeline for
# adding a room to the station.

const Sfx := preload("res://scripts/game/sfx.gd")

# the room the player is currently in - NPCs use contains_point() to
# hide themselves when they're somewhere you can't see
static var current: Node3D = null

@export var start_room := false
## shown in the top-left HUD; empty = the node name, spaced & uppercased
@export var display_name := ""
## rooms you can see INTO from this one (through doorways). Only used
## when show_neighbors is on; the list is kept either way.
@export var neighbors: Array[NodePath] = []
## OFF = only the current room renders; doorways are hard black.
## ON = adjacent rooms stay visible through their doorways.
@export var show_neighbors := false
## aim the camera at this world point on ready (position the camera in
## the editor, let the script handle rotation)
@export var camera_aim := false
@export var camera_look_at := Vector3(0, 1, 0)
## roll after aiming - the "something is wrong here" tilt; use sparingly
@export var camera_dutch_deg := 0.0

var _camera: Camera3D
var _trigger_cs: CollisionShape3D

# which room the player is in - static so all rooms agree; used to
# play the door sound only on genuine transitions
static var _active_room_name := ""


func _enter_tree() -> void:
	if start_room:
		_active_room_name = name


func _ready() -> void:
	add_to_group("room")
	for c in get_children():
		if c is Camera3D:
			_camera = c
			break
	if _camera != null and camera_aim:
		# camera_look_at is LOCAL to the room, so room scenes can be
		# placed anywhere
		_camera.look_at_from_position(_camera.global_position, to_global(camera_look_at))
		if camera_dutch_deg != 0.0:
			_camera.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(camera_dutch_deg))
	var trigger: Area3D = get_node_or_null("Trigger")
	if trigger != null:
		trigger.body_entered.connect(_on_body_entered)
		_trigger_cs = trigger.get_node_or_null("Shape")
	if start_room:
		activate.call_deferred()


# can a point be SEEN while this room is active? Inside it - or, when
# neighbors render (show_neighbors), inside a visible neighbor (the
# witness behind the observation glass stays visible)
func sees_point(p: Vector3, margin := 0.0) -> bool:
	if contains_point(p, margin):
		return true
	if not show_neighbors:
		return false
	for np in neighbors:
		var n := get_node_or_null(np)
		if n != null and n.has_method("contains_point") and n.contains_point(p, margin):
			return true
	return false


# make this room's MAIN camera current (used by cam zones to hand the
# shot back when the player steps out of a zone but stays in the room -
# activate() would no-op here since the room is already current)
func restore_main_camera() -> void:
	if _camera != null:
		_camera.make_current()


# world-space centre of this room's trigger volume - the resolver picks
# the nearest-centre room, so this must be the TRIGGER centre (where the
# player actually stands), not the room node origin
func room_center() -> Vector3:
	if _trigger_cs != null:
		return _trigger_cs.global_transform.origin
	return global_position


func contains_point(p: Vector3, margin := 0.0) -> bool:
	if _trigger_cs == null or not (_trigger_cs.shape is BoxShape3D):
		return true
	var local := _trigger_cs.global_transform.affine_inverse() * p
	var e: Vector3 = _trigger_cs.shape.size * 0.5 + Vector3(margin, margin, margin)
	return absf(local.x) <= e.x and absf(local.y) <= e.y and absf(local.z) <= e.z


func _on_body_entered(body: Node3D) -> void:
	# the player controller's _keep_room_current() is the SOLE authority
	# on which room is active (nearest-centre-that-contains-you, every
	# frame). This enter event only bootstraps the very first room before
	# the controller has run, so nothing starts black.
	if body.is_in_group("player") and current == null:
		activate()


func activate() -> void:
	# already the active room? do nothing. Both the trigger's body_entered
	# AND the player's _keep_room_current() can fire for the same change -
	# without this guard the door sound plays twice and the camera/vis
	# work runs redundantly.
	if current == self:
		return
	current = self
	var shown := [self]
	if show_neighbors:
		for np in neighbors:
			var n := get_node_or_null(np)
			if n != null:
				shown.append(n)
	for r in get_tree().get_nodes_in_group("room"):
		r.visible = r in shown
	# if the player is standing in one of our camera zones, that zone's
	# shot wins - entering a room through a door often clips the zone a
	# frame before the room trigger fires
	var cam := _camera
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player != null:
		for c in get_children():
			if c is Area3D and c.has_method("zone_camera") and c.overlaps_body(player):
				var zc: Camera3D = c.zone_camera()
				if zc != null:
					cam = zc
	if cam != null:
		cam.make_current()
	if _active_room_name != "" and _active_room_name != name:
		Sfx.play(self, "res://audio/sfx/door_close.mp3", -14.0)
	_active_room_name = name
	var hud := get_tree().get_first_node_in_group("room_label")
	if hud != null:
		var label := display_name
		if label == "":
			label = String(name).capitalize().to_upper()
		hud.set_room(label)
