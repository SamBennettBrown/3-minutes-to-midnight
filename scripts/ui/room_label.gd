extends CanvasLayer

# Current room name, BOTTOM-left - the top edge belongs to the intercom
# banner and the countdown. room.gd feeds it on every transition.

var _label: Label


func _enter_tree() -> void:
	add_to_group("room_label")


func _ready() -> void:
	layer = 104
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.offset_left = 70
	_label.offset_top = -70
	_label.offset_bottom = -40
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68))
	add_child(_label)


func set_room(text: String) -> void:
	_label.text = text
