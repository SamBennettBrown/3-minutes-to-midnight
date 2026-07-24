@tool
extends "res://scripts/player/player.gd"

# The junior cop: opens EVERY loop by bringing the detective his coffee
# and bugging him. He reads as comic relief - he is actually the final
# key to the whole puzzle.
#
# Loop opening beat: player input locks, he walks in from the doorway,
# dialogue auto-opens (variant picked by story flags - LAST entry whose
# flag is set wins, empty flag = always eligible), then the player is
# freed and he wanders to his post. He stays talkable afterwards and
# always speaks his newest variant.

@export var spawn_pos := Vector3(0, 0, -4.6)
@export var post_pos := Vector3(2.6, 0, -3.4)
@export var approach_speed := 1.9
@export var approach_distance := 1.3
## loop-clock time at which the approach starts (loop 0 delays him)
@export var start_delay := 0.0
## the room the rookie belongs to (his approach is CLAMPED to it, so he
## never chases the player through a wall into another room). Empty = the
## room named "Bullpen".
@export var home_room_path: NodePath

const Tuning := preload("res://scripts/game/tuning.gd")
var _state := "approach"
var _player_body: Node3D
var _dialogue_ui: Node
var _clock: Node
var _locked := false
var _intro_opened := false
var _talk_wait := 0.0
var _home_room: Node3D


func _ready() -> void:
	# his conversations use the rig's variant system (last match wins;
	# "once" lines fall through to the repeatable quip after first hear)
	if dialogue_variants.is_empty():
		dialogue_variants = [
			{"lines": [
				{"speaker": "ROOKIE PETTY", "text": "Filing, detective. So much filing. ...Shouldn't you be somewhere?"},
			]},
			{"once": true, "lines": [
				{"speaker": "ROOKIE PETTY", "text": "Coffee, detective! Two sugars, like always. You look like you slept at your desk again."},
				{"speaker": "DETECTIVE", "text": "Kid, I asked for this coffee two hours ago. My shift ends in three minutes."},
				{"speaker": "ROOKIE PETTY", "text": "...It's still warm. Mostly."},
			]},
		]
	strip_root_motion = true
	super._ready()
	add_to_group("talkable")
	global_position = spawn_pos


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	super._process(delta)
	if get_tree().paused:
		return
	match _state:
		"approach":
			# delay reads the loop clock, not an own timer - determinism
			if _clock == null:
				_clock = get_tree().get_first_node_in_group("loop_clock")
			if _clock == null or _clock.time < start_delay:
				# waiting for his cue: stand idle at his post, don't drift
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				return
			if not _locked:
				_locked = true
				_set_player_locked(true)
			if _player_body == null:
				_player_body = get_tree().get_first_node_in_group("player")
				if _player_body == null:
					return
			# clamp the chase target INTO the rookie's own room - he walks
			# to the player when they're here, and only to the room's edge
			# when they're not, so he can never straight-line through a wall
			var target := _clamp_to_home(_player_body.global_position)
			if _step_toward(target, approach_distance, delta, _approach_speed_now()):
				_face(_player_body.global_position)
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				_state = "talk"
		"talk":
			# the dialogue box may be busy (trinket beat) - retry until
			# free. Safety: if it never frees within ~8s (some other
			# dialogue stuck open), give up and unlock so the player is
			# never permanently frozen.
			if not _intro_opened:
				_talk_wait += delta
				if _talk_wait > 8.0:
					_intro_opened = true
					_finish_intro()
				else:
					_try_open_intro()
		"to_post":
			if _step_toward(post_pos, 0.15, delta, approach_speed):
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				_state = "posted"


# clamp a world point to lie inside the rookie's home room, so his
# approach target can never sit on the far side of a wall
func _clamp_to_home(p: Vector3) -> Vector3:
	if _home_room == null:
		if home_room_path != NodePath():
			_home_room = get_node_or_null(home_room_path)
		if _home_room == null:
			var rooms := get_tree().get_nodes_in_group("room")
			for r in rooms:
				if String(r.name) == "Bullpen":
					_home_room = r
					break
	if _home_room == null or not _home_room.has_method("contains_point"):
		return p
	if _home_room.contains_point(p, 0.0):
		return p
	# player is outside our room: aim for our room's centre instead of
	# chasing them out the door and through walls
	return _home_room.room_center()


func _approach_speed_now() -> float:
	# he learns the routine too: each loop he hustles harder, capped at
	# ~2x by the fourth night
	return approach_speed * minf(1.0 + 0.35 * float(maxi(Flags.loops - 1, 0)), 2.1)


func _step_toward(target: Vector3, stop_at: float, delta: float, speed: float) -> bool:
	var flat := target - global_position
	flat.y = 0.0
	if flat.length() <= stop_at:
		return true
	var dir := flat.normalized()
	global_position += dir * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 8.0)
	var running := speed > Tuning.RUN_PACE
	play("run" if running else "walk")
	if anim_player != null:
		anim_player.speed_scale = clampf(
				speed / (Tuning.RUN_PACE if running else Tuning.WALK_PACE), 0.7, 1.6)
	return false


func _face(target: Vector3) -> void:
	var d := target - global_position
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)


func _try_open_intro() -> void:
	_dialogue_ui = get_tree().get_first_node_in_group("dialogue")
	if _dialogue_ui == null:
		_intro_opened = true
		_finish_intro()
		return
	if _dialogue_ui.visible:
		return
	_intro_opened = true
	_dialogue_ui.closed.connect(_finish_intro, CONNECT_ONE_SHOT)
	var convo := get_conversation()
	_dialogue_ui.show_dialogue(convo.get("lines", []), convo.get("sets_flag", ""))


func _finish_intro() -> void:
	_set_player_locked(false)
	_state = "to_post"


func _set_player_locked(locked: bool) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.input_locked = locked
