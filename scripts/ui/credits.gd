extends CanvasLayer

# Credits: centred on a full black screen. Two ways in:
#  - the pause menu's CREDITS button -> open()      : closing unpauses back
#  - the WIN flow (endgame_director) -> open(true)  : closing RESETS the run
#    (all flags + loop count) and returns to the title screen, so the next
#    START plays the opening monologue fresh - the loop is broken, the story
#    starts over.

const TYPEWRITER := "res://fonts/Special_Elite/SpecialElite-Regular.ttf"
const Flags := preload("res://scripts/game/flags.gd")

var _bg: ColorRect
var _stats: Label
var _win_mode := false


func _enter_tree() -> void:
	add_to_group("credits")


func _ready() -> void:
	layer = 112
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 1)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_label(box, "LOOP GAME", 52, Color(0.95, 0.95, 0.93))
	_label(box, "a three-minute mystery by", 24, Color(0.65, 0.65, 0.62))
	_label(box, "ALEC DOBBELSTEYN", 36, Color(0.92, 0.92, 0.9))
	_label(box, "DAVID ESTEY", 36, Color(0.92, 0.92, 0.9))
	_label(box, "SAMWISE THE BRAVE", 36, Color(0.92, 0.92, 0.9))
	_label(box, " ", 20, Color.WHITE)
	_label(box, "thanks for playing our game", 28, Color(0.85, 0.82, 0.72), true)
	_label(box, " ", 20, Color.WHITE)

	_label(box, "our detective will return in", 24, Color(0.65, 0.65, 0.62))
	_label(box, "LOOP GAME 2: OVERTIME", 34, Color(0.9, 0.88, 0.8), true)
	_label(box, " ", 20, Color.WHITE)
	# the run stats - filled in when the WIN opens the credits
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_size_override("font_size", 26)
	_stats.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
	if ResourceLoader.exists(TYPEWRITER):
		_stats.add_theme_font_override("font", load(TYPEWRITER))
	_stats.visible = false
	box.add_child(_stats)
	_label(box, " ", 20, Color.WHITE)
	_label(box, "press E", 20, Color(0.55, 0.55, 0.52))
	visible = false


func _label(parent: Node, text: String, size: int, color: Color, typewriter := false) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if typewriter and ResourceLoader.exists(TYPEWRITER):
		l.add_theme_font_override("font", load(TYPEWRITER))
	parent.add_child(l)


func open(win := false) -> void:
	_win_mode = win
	if _stats != null:
		_stats.visible = win
		if win:
			var s := int(Flags.playtime)
			var clock := "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60] \
					if s >= 3600 else "%d:%02d" % [s / 60, s % 60]
			_stats.text = "the night looped %d times  -  %s on the clock" \
					% [Flags.loops, clock]
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
		if _win_mode:
			# the loop is broken - wipe the run (knowledge, holdings, loop
			# count) and return to the title. Next START = the intro again.
			Flags.clear()
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")