extends Node

# CAMERA TUNER - open this scene and press F6 (Play Scene).
#
#   TAB          next room          (teleports the detective there too)
#   Mouse        look around        (click once to capture the mouse)
#   W A S D      fly                (Q/E down/up, SHIFT = fast)
#   Wheel        zoom (fov)
#   ENTER        save this room's shot
#   ESC          release mouse / quit
#
# Saved shots land in scripts/tools/frames/cam_tuning.txt as ready-to-
# paste transforms - hand the file to Claude to bake them into the
# room scenes.

const Flags := preload("res://scripts/game/flags.gd")
const SAVE_PATH := "res://scripts/tools/frames/cam_tuning.txt"

var _rooms: Array = []
var _idx := -1
var _cam: Camera3D
var _hud: Label
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Flags.set_flag("intro_done")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	_cam = Camera3D.new()
	add_child(_cam)
	var layer := CanvasLayer.new()
	layer.layer = 125
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(40, 40)
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	layer.add_child(_hud)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = true
	_rooms = get_tree().get_nodes_in_group("room")
	_rooms.sort_custom(func(a, b): return String(a.name) < String(b.name))
	DirAccess.make_dir_recursive_absolute("res://scripts/tools/frames")
	_next_room()


func _next_room() -> void:
	_idx = (_idx + 1) % _rooms.size()
	var room: Node3D = _rooms[_idx]
	room.activate()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		p.global_position = room.global_position + Vector3(0, 0, 0)
	# start from the room's current camera so you tune, not rebuild
	for c in room.get_children():
		if c is Camera3D:
			_cam.global_transform = c.global_transform
			_cam.fov = c.fov
			break
	var e := _cam.global_transform.basis.get_euler()
	_yaw = e.y
	_pitch = e.x
	_cam.make_current()
	_update_hud("")


func _update_hud(extra: String) -> void:
	_hud.text = "TUNER  [%d/%d]  %s   —  TAB next · ENTER save · wheel fov %d°  %s" % [
		_idx + 1, _rooms.size(), _rooms[_idx].name, int(_cam.fov), extra]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = clampf(_cam.fov - 2.0, 15.0, 90.0)
			_update_hud("")
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = clampf(_cam.fov + 2.0, 15.0, 90.0)
			_update_hud("")
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.2, 1.2)
		_cam.global_transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0))
	elif event is InputEventKey and event.pressed and not event.is_echo():
		match event.physical_keycode:
			KEY_TAB:
				_next_room()
			KEY_ENTER:
				_save_shot()
			KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					get_tree().quit()


func _save_shot() -> void:
	var room: Node3D = _rooms[_idx]
	var t := room.global_transform.affine_inverse() * _cam.global_transform
	var b := t.basis
	var o := t.origin
	var line := "%s|fov %.0f|Transform3D(%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f)" % [
		room.name, _cam.fov,
		b.x.x, b.y.x, b.z.x, b.x.y, b.y.y, b.z.y, b.x.z, b.y.z, b.z.z,
		o.x, o.y, o.z]
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(SAVE_PATH) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()
	print("TUNER saved: ", line)
	_update_hud("  ✔ SAVED")


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir -= _cam.global_transform.basis.z
	if Input.is_physical_key_pressed(KEY_S):
		dir += _cam.global_transform.basis.z
	if Input.is_physical_key_pressed(KEY_A):
		dir -= _cam.global_transform.basis.x
	if Input.is_physical_key_pressed(KEY_D):
		dir += _cam.global_transform.basis.x
	if Input.is_physical_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		dir -= Vector3.UP
	var speed := 8.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.0
	_cam.global_position += dir * speed * delta
