extends CanvasLayer

# Code-entry UI for keypads. Fira Code digits, left-anchored tilted
# panel like the rest of the UI. Pauses the world while open. Type
# digits or click them; Enter/OK submits, Esc cancels.
# Success: keycard.mp3 + flag. Failure: static.wav + clear.

const Flags := preload("res://scripts/game/flags.gd")

var _code := ""
var _flag := ""
var _on_success := Callable()
var _entered := ""
var _display: Label
var _box: VBoxContainer
var _audio: AudioStreamPlayer
var _mono_font: FontFile


func _ready() -> void:
	layer = 107
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("keypad_ui")
	_mono_font = load("res://fonts/Fira_Code/FiraCode-VariableFont_wght.ttf")
	# a dark wash so the pad owns the screen while it's up
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_box = VBoxContainer.new()
	# CENTRED - the lock is the whole moment
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = -140.0
	_box.offset_top = -220.0
	_box.rotation_degrees = -4.0
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	var esc := Label.new()
	esc.text = "ESC — step away"
	esc.anchor_left = 0.0
	esc.anchor_right = 1.0
	esc.anchor_top = 1.0
	esc.anchor_bottom = 1.0
	esc.offset_top = -70.0
	esc.offset_bottom = -40.0
	esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc.add_theme_font_size_override("font_size", 22)
	esc.add_theme_color_override("font_color", Color(0.68, 0.68, 0.64))
	add_child(esc)

	var title := Label.new()
	title.text = "KEYPAD"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_box.add_child(title)

	_display = Label.new()
	_display.add_theme_font_size_override("font_size", 44)
	_display.add_theme_color_override("font_color", Color(0.7, 0.95, 0.75))
	if _mono_font != null:
		_display.add_theme_font_override("font", _mono_font)
	_box.add_child(_display)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	for t in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "OK"]:
		var b := Button.new()
		b.text = t
		b.flat = true
		b.custom_minimum_size = Vector2(80, 48)
		b.add_theme_font_size_override("font_size", 30)
		if _mono_font != null:
			b.add_theme_font_override("font", _mono_font)
		b.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88))
		b.add_theme_color_override("font_hover_color", Color(0.7, 0.95, 0.75))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_press.bind(t))
		grid.add_child(b)

	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -8.0
	add_child(_audio)
	visible = false


func open(code: String, flag: String, on_success: Callable = Callable()) -> void:
	_code = code
	_flag = flag
	_on_success = on_success
	_entered = ""
	visible = true
	get_tree().paused = true
	_play("res://audio/sfx/button_beep.mp3")
	_update()


func _update() -> void:
	var s := ""
	for i in _code.length():
		s += (_entered[i] if i < _entered.length() else "_")
		s += " "
	_display.text = s


func _press(t: String) -> void:
	if t == "OK":
		_submit()
		return
	# every key answers with a beep - the pad feels wired-in
	_play("res://audio/sfx/button_beep.mp3")
	if t == "CLR":
		_entered = ""
	elif _entered.length() < _code.length():
		_entered += t
	_update()


func _submit() -> void:
	if _entered == _code:
		if _flag != "":
			Flags.set_flag(_flag)
		# a mechanical unlatch - keycard.mp3 belongs to the evidence-room
		# door alone, so the pad answers with its own click
		_play("res://audio/sfx/click.mp3")
		_close()
		# tell the keypad prop the code went through (opens the passage,
		# plays the reveal) - AFTER closing so the world is unpaused
		if _on_success.is_valid():
			_on_success.call()
	else:
		_play("res://audio/ambient/static.wav")
		_entered = ""
		_update()


func _close() -> void:
	visible = false
	get_tree().paused = false


func _play(path: String) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.play()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	get_viewport().set_input_as_handled()
	var k: int = event.physical_keycode
	if k == KEY_ESCAPE:
		_close()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		_submit()
	elif k == KEY_BACKSPACE:
		_play("res://audio/sfx/button_beep.mp3")
		_entered = _entered.left(-1)
		_update()
	elif k >= KEY_0 and k <= KEY_9:
		_press(String.chr(k))
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		_press(str(k - KEY_KP_0))
