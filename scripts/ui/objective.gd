extends CanvasLayer

# The current task, top-right. One line, quiet, always readable.
# From anywhere:
#   get_tree().get_first_node_in_group("objective").set_task("Clock out.")
#   get_tree().get_first_node_in_group("objective").clear_task()

var _label: Label


func _enter_tree() -> void:
	add_to_group("objective")


func _ready() -> void:
	layer = 104
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.position = Vector2(-70, 46)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.88, 0.85, 0.74))
	_label.visible = false
	add_child(_label)


func set_task(text: String) -> void:
	_label.text = text
	_label.visible = text != ""
	if _label.visible:
		# small settle-in so a new task catches the eye
		_label.pivot_offset = Vector2(_label.size.x, 0)
		_label.scale = Vector2(1.12, 1.12)
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_label, "scale", Vector2.ONE, 0.25) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func clear_task() -> void:
	set_task("")
