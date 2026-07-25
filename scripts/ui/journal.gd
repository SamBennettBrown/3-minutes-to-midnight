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

const NOTE_FONT := preload("res://fonts/Special_Elite/SpecialElite-Regular.ttf")

@export var entries: Array = [
	{"flag": "bound_promise", "title": "THE TRINKET",
		"text": "He {who is he?} pressed a small brass charm into my pocket."},
	{"flag": "know_loop", "title": "THREE MINUTES",
		"text": "It's the heirloom. He dies at midnight and it drags me back to 11:57 - three minutes, over and over. If I can change how the night goes, maybe he lives. Start where they took him: interrogation."},
	{"flag": "found_note_57", "title": "THE NOTE",
		"text": "Clutched in the dead mans {who is the dead man} hand: a scrap of paper, one number scrawled on it - 57. Too short for a phone. A badge number. Someone's badge number."},
	{"flag": "read_case_file", "title": "CASE FILE 44-C",
		"text": "Victim found 11:40 PM. The murder weapon was never logged into evidence. Someone signed the lockup sheet that night."},
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
var _toast_root: Control
var _toast_box: VBoxContainer
var _toast_label: Label
var _toast_tween: Tween


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
	var boxRotation = .15
	box.position = Vector2(70, 130)
	box.rotation_degrees = boxRotation
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	var title := Label.new()
	title.text = "CASE FILE"
	title.add_theme_font_override("font", NOTE_FONT)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
	title.rotation_degrees = (boxRotation * -1) # zero out the degrees between the box and the text for a straight line
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
	if _toast_root == null:
		var layer := CanvasLayer.new()
		layer.layer = 103
		add_child(layer)
		_toast_root = Control.new()
		_toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_toast_root)

		# a small stack, dropped near the top-centre of the screen so it's
		# impossible to miss the moment a new lead lands
		_toast_box = VBoxContainer.new()
		_toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_toast_box.add_theme_constant_override("separation", 4)
		_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_root.add_child(_toast_box)

		_toast_label = Label.new()
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.add_theme_font_override("font", NOTE_FONT)
		_toast_label.add_theme_font_size_override("font_size", 34)
		_toast_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.79))
		# a hard shadow keeps it legible over the bright bullpen
		_toast_label.add_theme_constant_override("shadow_offset_x", 2)
		_toast_label.add_theme_constant_override("shadow_offset_y", 2)
		_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		_toast_box.add_child(_toast_label)

		var sub := Label.new()
		sub.text = "— press Tab to open your case file —"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_override("font", NOTE_FONT)
		sub.add_theme_font_size_override("font_size", 18)
		sub.add_theme_color_override("font_color", Color(0.78, 0.75, 0.65))
		sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		sub.add_theme_constant_override("shadow_offset_x", 1)
		sub.add_theme_constant_override("shadow_offset_y", 1)
		_toast_box.add_child(sub)

	_toast_label.text = text
	_toast_root.visible = true
	Sfx.play(self, "res://audio/sfx/journal_entry.mp3", -8.0)

	# wait one frame so the box reports its real size, then centre it
	# horizontally near the top and pivot scaling from its middle
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var box_size := _toast_box.get_combined_minimum_size()
	_toast_box.position = Vector2((vp.x - box_size.x) * 0.5, vp.y * 0.11)
	_toast_box.pivot_offset = box_size * 0.5
	_toast_box.rotation_degrees = -1.5

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_box.scale = Vector2(0.8, 0.8)
	_toast_box.modulate.a = 0.0
	_toast_tween = create_tween()
	# pop IN with a little overshoot, hold, then fade + shrink OUT
	_toast_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_toast_tween.tween_property(_toast_box, "scale", Vector2.ONE, 0.3)
	_toast_tween.parallel().tween_property(_toast_box, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(3.0)
	_toast_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_toast_tween.tween_property(_toast_box, "modulate:a", 0.0, 0.4)
	_toast_tween.parallel().tween_property(_toast_box, "scale", Vector2(0.92, 0.92), 0.4)
	_toast_tween.tween_callback(func(): _toast_root.visible = false)


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
		# Each note gets its own little slate so it can sit at its own
		# angle - like separate scribbles on the page, not a tidy grid.
		var note := VBoxContainer.new()
		note.add_theme_constant_override("separation", 4)
		note.rotation_degrees = _jitter(idx, 11, 2.4)
		note.custom_minimum_size = Vector2(500, 0)
		col.add_child(note)
		# ink pools and fades a shade from note to note
		var ink := Color(0.9, 0.86, 0.77) + Color(1, 1, 1) * _jitter(idx, 5, 0.05)
		_add_label(note, "•  " + String(e.get("title", "")), 28, ink)
		_add_label(note, String(e.get("text", "")), 22, Color(0.93, 0.91, 0.86), 500.0)
		_add_label(col, " ", 14, Color.WHITE)
		idx += 1
	if idx == 0:
		_add_label(_cols[0], "Nothing yet. Watch. Listen. Remember.", 24, Color(0.7, 0.7, 0.7))


# Deterministic per-note wobble: same note always sits at the same
# angle/offset within a session, but each differs from its neighbours.
func _jitter(idx: int, span: int, scale: float) -> float:
	return (float((idx * 2654435761) % span) - float(span - 1) * 0.5) / (float(span) * 0.5) * scale


func _add_label(parent: Node, text: String, size: int, color: Color, wrap_width := 0.0) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", NOTE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	parent.add_child(l)
