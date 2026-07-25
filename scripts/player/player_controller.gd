extends CharacterBody3D

const Tuning := preload("res://scripts/game/tuning.gd")
const Interact := preload("res://scripts/game/interact.gd")

# Player movement + interaction for fixed-camera rooms. The rig child
# owns how the character LOOKS; this owns how it MOVES and what E does.
#
# Two schemes, switchable per-instance in the Inspector:
#  - Camera Relative (default): input follows the live camera. The
#    mapping LATCHES while keys are held, so a hard camera cut mid-walk
#    never flips your direction - you re-map only on a fresh press.
#  - Tank: forward/back along the body's facing, left/right rotate.

const Sfx := preload("res://scripts/game/sfx.gd")

@export_enum("Camera Relative", "Tank") var control_scheme := 0
@export var walk_speed := 2.2
@export var run_speed := 4.2
## tank only: reversing is slower than walking
@export var back_speed := 1.3
## tank only: rotation speed in radians/sec
@export var turn_speed := 2.8
## camera-relative: how quickly the body turns into the move direction
@export var face_speed := 10.0
## ground accel / decel (m/s^2). Fast enough to stay snappy, but no more
## instant-velocity skating on starts, stops and turns
@export var accel := 18.0
@export var decel := 26.0
## how close a "talkable" must be for E to interact
@export var talk_range := Tuning.INTERACT_RANGE

@onready var rig: Node3D = $Rig

# set by scripted beats (loop intro, cutscenes) to hold the player still
var input_locked := false

var _latch_valid := false
var _latched_fwd := Vector3.FORWARD
var _latched_right := Vector3.RIGHT
var _bump_cd := 0.0
var _slow_time := 0.0


# Movement runs at RENDER rate (in _process, below), not on physics ticks.
# The player used to advance in fixed 60Hz physics steps while every NPC
# glided at frame rate - side by side that reads as jagged stutter,
# especially on high-refresh screens. Everything the player collides with
# here is static geometry, so move_and_slide at render rate is safe.
func _move(delta: float) -> void:
	var input := Vector2.ZERO if input_locked \
			else Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var running := Input.is_action_pressed("sprint")
	var moving: bool
	if control_scheme == 1:
		moving = _move_tank(input, running, delta)
	else:
		moving = _move_camera_relative(input, running, delta)

	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()

	# the animation follows what actually HAPPENED, not what was asked for -
	# but with a short grace window, because the accel ramp passes through
	# ~zero speed on a direction reversal and a raw threshold would flap the
	# clip walk->idle->walk on every wiggle. Sustained blockage (walking
	# into a wall) still drops to idle - no moonwalking.
	var hv := Vector2(velocity.x, velocity.z).length()
	if not moving or hv > 0.3:
		_slow_time = 0.0
	else:
		_slow_time += delta
	_update_animation(moving and _slow_time < 0.15, running)
	_check_bump(delta, moving)


func _move_tank(input: Vector2, running: bool, delta: float) -> bool:
	rotate_y(-input.x * turn_speed * delta)
	var speed := run_speed if running else walk_speed
	if input.y < 0.0:
		speed = back_speed
	var flat := transform.basis.z * input.y * speed
	velocity.x = flat.x
	velocity.z = flat.z
	return absf(input.y) > 0.05


func _move_camera_relative(input: Vector2, running: bool, delta: float) -> bool:
	if input == Vector2.ZERO:
		_latch_valid = false
		# ease to a stop over ~0.1s instead of freezing mid-stride
		var stop := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, decel * delta)
		velocity.x = stop.x
		velocity.z = stop.y
		return false
	if not _latch_valid:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_latched_fwd = -cam.global_transform.basis.z
			_latched_fwd.y = 0.0
			_latched_fwd = _latched_fwd.normalized()
			_latched_right = cam.global_transform.basis.x
			_latched_right.y = 0.0
			_latched_right = _latched_right.normalized()
			_latch_valid = true
	var dir := _latched_right * input.x + _latched_fwd * input.y
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := run_speed if running else walk_speed
	# ramp toward the target velocity - kills the instant-speed skate on
	# starts and hard direction changes while staying responsive (~0.12s).
	# One VECTOR move_toward, not per-axis: per-axis ramps kink the velocity
	# direction mid-turn, which reads as a jagged little hitch on corners.
	var v := Vector2(velocity.x, velocity.z) \
			.move_toward(Vector2(dir.x, dir.z) * speed, accel * delta)
	velocity.x = v.x
	velocity.z = v.y
	if dir.length() > 0.1:
		var target := atan2(dir.x, dir.z)
		# small deadband so the heading isn't micro-corrected every tick
		# (walk wobble) - but tight enough that the body never settles
		# visibly askew from its travel direction
		if absf(angle_difference(rotation.y, target)) > 0.015:
			rotation.y = lerp_angle(rotation.y, target, face_speed * delta)
	return true


func _update_animation(moving: bool, running: bool) -> void:
	var clip := "idle"
	if moving:
		clip = "run" if running else "walk"
	rig.play(clip)  # rig dedupes and crossfades internally
	# feet grip the floor: scale the clip to actual speed
	if rig.anim_player != null:
		var hv := Vector2(velocity.x, velocity.z).length()
		match clip:
			"walk":
				rig.anim_player.speed_scale = clampf(hv / Tuning.WALK_PACE, 0.7, 1.4)
			"run":
				rig.anim_player.speed_scale = clampf(hv / Tuning.RUN_PACE, 0.8, 1.4)
			_:
				rig.anim_player.speed_scale = 1.0


func _check_bump(delta: float, moving: bool) -> void:
	# soft thud when you walk into somebody
	_bump_cd -= delta
	if not moving or _bump_cd > 0.0:
		return
	var col := get_last_slide_collision()
	if col == null:
		return
	var hit := col.get_collider() as Node
	if hit is StaticBody3D and hit.get_parent() != null and hit.get_parent().has_method("bark"):
		_bump_cd = 2.0
		Sfx.play_at(self, "res://audio/sfx/bump.mp3", -10.0)


# --- interaction ---

const RoomState := preload("res://scripts/game/room.gd")


func _process(delta: float) -> void:
	_move(delta)
	if Input.is_action_just_pressed("interact") and not input_locked:
		_try_talk()
	_keep_room_current()


# Fixed-camera room ownership - ONE authoritative rule, works for every
# room, no per-room tuning, cannot ping-pong.
#
# The active room is the one whose FLOOR you're standing over. A floor's
# footprint ends at that room's walls, so the camera flips exactly as you
# cross a doorway - never 0.8 m late into an unrendered void (which is
# what the oversized ENTRY triggers would do). Floors of neighbouring
# rooms meet at the shared wall; a small SEAM margin gives them a hair of
# overlap so standing on the boundary can't flicker (nearest floor-centre
# wins the tie). If you're over NO floor (in a wall/doorway sliver, or a
# corridor gap), keep the room you were in - never cut to black.
const SEAM := 0.25

func _keep_room_current() -> void:
	var cur = RoomState.current
	var pos := global_position
	var best: Node3D = null
	var best_d := INF
	for r in get_tree().get_nodes_in_group("room"):
		if not r.contains_floor_point(pos, SEAM):
			continue
		var d: float = r.floor_center().distance_to(pos)
		if d < best_d:
			best_d = d
			best = r
	# over no floor (doorway sliver / corridor gap): hold the current room,
	# unless it was freed by a scene reload
	if best == null:
		return
	if best == cur:
		return
	best.activate()


func _try_talk() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null:
		return
	var nearest := _nearest_talkable()
	if nearest == null:
		return
	# custom interactions (keypads, machines) override the dialogue path
	if nearest.has_method("interact"):
		nearest.interact()
		return
	# characters pick flag/time-conditional variants atomically
	if nearest.has_method("get_conversation"):
		var convo: Dictionary = nearest.get_conversation()
		dlg.show_dialogue(convo.get("lines", []), convo.get("sets_flag", ""))
		return
	# plain interactables: static dialogue + flag
	var flag := ""
	if "sets_flag" in nearest:
		flag = nearest.sets_flag
	dlg.show_dialogue(nearest.dialogue, flag)


func _nearest_talkable() -> Node:
	return Interact.nearest(get_tree(), global_position, talk_range)
