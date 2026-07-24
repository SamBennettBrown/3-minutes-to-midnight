extends CanvasLayer

# Credits: opened from the pause menu via open(). Esc / E / Enter
# closes. (A win flow will also call open() once the accusation/win
# screen exists - not built yet; every ending currently routes to the
# lose screen.)

const TYPEWRITER := "res://fonts/Special_Elite/SpecialElite-Regular.ttf"

var _bg: ColorRect


func _enter_tree() -> void:
	add_to_group("credits")


func _ready() -> void:
	layer = 112
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.88)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	add_child(_bg)

	var box := VBoxContainer.new()
	box.position = Vector2(70, 180)
	box.rotation_degrees = -8.0
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_label(box, "LOOP GAME", 52, Color(0.95, 0.95, 0.93))
	_label(box, "a three-minute mystery by", 24, Color(0.65, 0.65, 0.62))
	_label(box, "ALEC DOBBELSTEYN", 36, Color(0.92, 0.92, 0.9))
	_label(box, "DAVID ESTEY", 36, Color(0.92, 0.92, 0.9))
	_label(box, "SAMWISE THE BRAVE", 36, Color(0.92, 0.92, 0.9))
	_label(box, "CLAUDE", 36, Color(0.92, 0.92, 0.9))
	_label(box, " ", 20, Color.WHITE)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(980, 0)
	rt.add_theme_font_size_override("normal_font_size", 30)
	rt.text = "OUR DETECTIVE WILL RETURN IN [s]AVENGERS: DOOMSDAY[/s]"
	box.add_child(rt)

	var scrawl := Label.new()
	scrawl.text = "LOOP GAME 2: OVERTIME"
	scrawl.add_theme_font_size_override("font_size", 34)
	scrawl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	if ResourceLoader.exists(TYPEWRITER):
		scrawl.add_theme_font_override("font", load(TYPEWRITER))
	scrawl.rotation_degrees = -2.0
	box.add_child(scrawl)

	_label(box, " ", 20, Color.WHITE)
	_label(box, "esc to close", 20, Color(0.55, 0.55, 0.52))
	visible = false


func _label(parent: Node, text: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)


func open() -> void:
	visible = true
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	var k: int = event.physical_keycode
	if k == KEY_ESCAPE or k == KEY_E or k == KEY_ENTER:
		get_viewport().set_input_as_handled()
		visible = false
		get_tree().paused = false
