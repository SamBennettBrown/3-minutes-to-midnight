extends CanvasLayer

# The case file: everything the detective KNOWS. J or Tab opens it and
# pauses the world; the screen dims behind it for readability. Facts
# fill three columns (plenty for the whole mystery). Knowledge survives
# loop restarts; objects don't.
#
# Opening it while the pause menu is up (or vice versa) SWITCHES
# between the two.
#
# Author entries here (or override on the node): each is
#   {"flag": ..., "title": ..., "text": ...}
# shown only once its flag is set.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")
const Tuning := preload("res://scripts/game/tuning.gd")

@export var entries: Array = [
	{"flag": "bound_promise", "title": "THE TRINKET",
		"text": "He pressed a small brass charm into my pocket. 'Help me.' It's warm, and it ticks. Midnight keeps coming back. So do I."},
	{"flag": "read_case_file", "title": "CASE FILE 44-C",
		"text": "Victim found 11:40 PM. The murder weapon was never logged into evidence. Someone signed the lockup sheet that night."},
	{"flag": "know_code", "title": "MAINTENANCE SLIP",
		"text": "Cell-block keypad temp code: " + Tuning.CELLS_CODE + ". Nobody ever changed it."},
	{"flag": "cells_unlocked", "title": "THE CELL BLOCK",
		"text": "The temp code works. That door was opened the night of the murder - by someone who knew the code."},
	{"flag": "overheard_call", "title": "THE PHONE CALL",
		"text": "Someone called the front desk asking if I was still in the building. The receptionist said she'd 'let him know.'"},
	{"flag": "know_weight_trap", "title": "THE SPRING PLATE",
		"text": "The unlogged package in evidence sits on a weight-sensitive plate. Lifting it bare rings every bell in the building. It wants a stand-in - about a pound."},
	{"flag": "found_murder_weapon", "title": "THE PACKAGE",
		"text": "A service revolver, serial filed, never logged into evidence. Hidden in plain sight in the one room only a badge can enter. This is what killed the clerk."},
	{"flag": "inmate_tip", "title": "THE INMATE'S TIP",
		"text": "A guest of the cell block says word inside was somebody wanted the witness gone - somebody CLOSE. He thinks the witness was safer behind bars. Safer from someone with a badge."},
	{"flag": "heard_bell_logbook", "title": "THE RADIO LOG",
		"text": "Night shift collects the radio log at the front desk - ALL of it, captain's orders. Somebody wants tonight's record out of circulation."},
]

var _dim: ColorRect
var _cols: Array = []
var _toast: Label
var _toast_timer := 0.0


func _enter_tree() -> void:
	add_to_group("journal")


func _ready() -> void:
	layer = 106
	process_mode = Node.PROCESS_MODE_ALWAYS

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var box := VBoxContainer.new()
	box.position = Vector2(70, 130)
	box.rotation_degrees = -8.0
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	var title := Label.new()
	title.text = "CASE FILE"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 46)
	box.add_child(row)
	for i in 3:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.custom_minimum_size = Vector2(520, 0)
		row.add_child(col)
		_cols.append(col)

	visible = false

	# "case file updated" toast - lives outside the journal page so it
	# shows during play; the layer stays visible, the page doesn't
	Flags.subscribe(_on_flag_set)


func _on_flag_set(flag: String) -> void:
	for e in entries:
		if String(e.get("flag", "")) == flag:
			_show_toast("CASE FILE UPDATED  —  " + String(e.get("title", "")))
			return


func _show_toast(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 103
		add_child(layer)
		_toast = Label.new()
		_toast.position = Vector2(70, 90)
		_toast.rotation_degrees = -8.0
		_toast.add_theme_font_size_override("font_size", 26)
		_toast.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
		layer.add_child(_toast)
	_toast.text = text
	_toast.visible = true
	_toast_timer = 3.5
	Sfx.play(self, "res://audio/sfx/journal_entry.mp3", -8.0)


func _process(delta: float) -> void:
	if _toast_timer > 0.0 and not get_tree().paused:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast != null:
			_toast.visible = false


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	var k: int = event.physical_keycode
	if k != KEY_J and k != KEY_TAB:
		return
	if not visible:
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null and dlg.visible:
			return
		# switch: if the pause menu is up, close it and open the journal
		var menu := get_tree().get_first_node_in_group("options_menu")
		if menu != null and menu.visible:
			menu._toggle_open()
	get_viewport().set_input_as_handled()
	_toggle()


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	Sfx.play(self, "res://audio/sfx/journal.mp3", -6.0)
	if visible:
		_rebuild()


func _rebuild() -> void:
	for col in _cols:
		for c in col.get_children():
			c.queue_free()
	var unlocked: Array = entries.filter(
			func(e): return Flags.has_flag(String(e.get("flag", ""))))
	# fill DOWN each column before spilling into the next
	var per_col := maxi(ceili(float(unlocked.size()) / 3.0), 1)
	var idx := 0
	for e in unlocked:
		var col: VBoxContainer = _cols[idx / per_col]
		_add_label(col, String(e.get("title", "")), 28, Color(0.85, 0.82, 0.7))
		_add_label(col, String(e.get("text", "")), 22, Color(0.92, 0.92, 0.9), 500.0)
		_add_label(col, " ", 12, Color.WHITE)
		idx += 1
	if idx == 0:
		_add_label(_cols[0], "Nothing yet. Watch. Listen. Remember.", 24, Color(0.7, 0.7, 0.7))


func _add_label(parent: Node, text: String, size: int, color: Color, wrap_width := 0.0) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	parent.add_child(l)
