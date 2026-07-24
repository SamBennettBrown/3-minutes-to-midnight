extends CanvasLayer

# Current room name, top-left. room.gd feeds it on every transition.

var _label: Label


func _enter_tree() -> void:
	add_to_group("room_label")


func _ready() -> void:
	layer = 104
	_label = Label.new()
	_label.position = Vector2(70, 40)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68))
	add_child(_label)


func set_room(text: String) -> void:
	_label.text = text
