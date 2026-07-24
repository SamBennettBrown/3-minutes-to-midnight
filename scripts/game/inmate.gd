@tool
extends "res://scripts/game/npc.gd"

# A guest of the cell block. Talking to him is a scene: the camera
# pushes in through the bars to a face-to-face shot, holds for the
# conversation, and eases back to the room camera when it ends.

## where the talk camera sits, relative to the inmate (corridor side)
@export var cam_offset := Vector3(-2.2, 1.5, 0.6)
@export var cam_fov := 40.0
@export var push_in_time := 0.7

var _talk_cam: Camera3D
var _prev_cam: Camera3D


func interact() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	var convo := get_conversation()
	_prev_cam = get_viewport().get_camera_3d()
	if _prev_cam == null:
		return  # no camera current this frame (mid room hand-off)
	if _talk_cam == null:
		_talk_cam = Camera3D.new()
		add_child(_talk_cam)
	_talk_cam.fov = _prev_cam.fov
	_talk_cam.global_transform = _prev_cam.global_transform
	_talk_cam.make_current()
	var target := global_position + cam_offset
	var look := global_position + Vector3(0, 1.45, 0)
	var dest := Transform3D(Basis.looking_at((look - target).normalized()), target)
	_glide(_talk_cam.global_transform, dest, cam_fov)
	dlg.show_dialogue(convo.get("lines", []), convo.get("sets_flag", ""))
	dlg.closed.connect(_end_talk, CONNECT_ONE_SHOT)


func _end_talk() -> void:
	if _talk_cam == null or _prev_cam == null or not is_instance_valid(_prev_cam):
		return
	var back := _glide(_talk_cam.global_transform, _prev_cam.global_transform, _prev_cam.fov)
	back.tween_callback(func() -> void:
		if is_instance_valid(_prev_cam):
			_prev_cam.make_current())


func _glide(from: Transform3D, to: Transform3D, fov: float) -> Tween:
	var tw := create_tween()
	# the dialogue pauses the tree - the camera move must not freeze
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(f: float) -> void:
		_talk_cam.global_transform = from.interpolate_with(to, f), 0.0, 1.0, push_in_time)
	tw.parallel().tween_property(_talk_cam, "fov", fov, push_in_time)
	return tw
