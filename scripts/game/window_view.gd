extends Node3D

# The two-way mirror. Interact with the glass and the view cuts to a
# camera INSIDE interrogation (which we reveal just for the peek, since
# rooms are otherwise isolated). The world keeps running while you watch
# - the whole point of the observation room. ESC returns to observation.
#
# Wiring: point `peek_camera` at a Camera3D placed inside the
# interrogation room (aimed at the witness), and `peek_room` at the
# Interrogation Room node so we can toggle its visibility for the peek.

const RoomState := preload("res://scripts/game/room.gd")

## a Camera3D inside interrogation, framing the witness
@export var peek_camera: NodePath
## the Interrogation Room node (revealed only during the peek)
@export var peek_room: NodePath
@export var prompt_height := 0.5

## the cold cast of the two-way glass / security monitor over the peek
@export var tint_color := Color(0.15, 0.35, 0.75, 0.28)

var _prev_cam: Camera3D
var _watching := false
var _hint_layer: CanvasLayer
var _hint: Label
var _tint: ColorRect


func _ready() -> void:
	add_to_group("talkable")


func interact() -> void:
	if _watching:
		return
	var cam := get_node_or_null(peek_camera) as Camera3D
	if cam == null:
		return
	_watching = true
	# claim ESC + block the pause menu while peeking (options_menu checks
	# this group before opening)
	add_to_group("active_peek")
	_prev_cam = get_viewport().get_camera_3d()
	# reveal interrogation just for the peek, then look through its camera
	var room := get_node_or_null(peek_room)
	if room != null:
		room.visible = true
	cam.make_current()
	_set_tint(true)
	# while looking through the glass, the label should say where you're
	# LOOKING, not where you're standing
	var rl := get_tree().get_first_node_in_group("room_label")
	if rl != null:
		rl.set_room("INTERROGATION")
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.input_locked = true
	_show_hint("ESC — step back")


func _input(event: InputEvent) -> void:
	if not _watching:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_step_back()


func _step_back() -> void:
	_watching = false
	remove_from_group("active_peek")
	_set_tint(false)
	if _hint != null:
		_hint.visible = false
	# re-hide interrogation and restore observation's camera
	var room := get_node_or_null(peek_room)
	if room != null and RoomState.current != room:
		room.visible = false
	if is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	var rl := get_tree().get_first_node_in_group("room_label")
	if rl != null and RoomState.current != null:
		var label: String = RoomState.current.display_name
		if label == "":
			label = String(RoomState.current.name).capitalize().to_upper()
		rl.set_room(label)
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.input_locked = false


func _show_hint(text: String) -> void:
	if _hint == null:
		_hint_layer = CanvasLayer.new()
		_hint_layer.layer = 109
		add_child(_hint_layer)
		_hint = Label.new()
		_hint.anchor_top = 1.0
		_hint.anchor_bottom = 1.0
		_hint.position = Vector2(70, -70)
		_hint.add_theme_font_size_override("font_size", 24)
		_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
		_hint_layer.add_child(_hint)
	_hint.text = text
	_hint.visible = true


# a full-screen blue wash while peeking - the cold light of the glass.
# Its own layer BELOW the hint text so "ESC - step back" stays legible.
func _set_tint(on: bool) -> void:
	if _tint == null:
		var layer := CanvasLayer.new()
		layer.layer = 108
		add_child(layer)
		_tint = ColorRect.new()
		_tint.color = tint_color
		_tint.anchor_right = 1.0
		_tint.anchor_bottom = 1.0
		_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_tint)
	_tint.visible = on
