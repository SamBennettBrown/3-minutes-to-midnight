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

@export var entries: Array = [
	{"flag": "bound_promise", "title": "THE TRINKET",
		"text": "He pressed a small brass charm into my pocket. 'Help me.' It's warm, and it ticks. Midnight keeps coming back. So do I."},
	{"flag": "know_impossible_death", "title": "THE IMPOSSIBLE DEATH",
		"text": "My witness dies in the cell block every loop - shot, in a room holding only one prisoner, and that prisoner has no gun. It can't happen, but it does. The only ones who'd know what really went on in there are the ones who were in there. Start in the cells."},
	{"flag": "saw_wall_shot", "title": "THE SHOT FROM THE WALL",
		"text": "I waited in the cells at midnight and saw it myself. The muzzle-flash came from INSIDE THE WALL - through solid concrete - and he dropped. I was right there and couldn't stop it. There's a way into that block I can't see. Find it, and I get to the other side of the killer."},
	{"flag": "heard_evidence_tip", "title": "OVERHEARD - INTERROGATION",
		"text": "Through the two-way glass: the investigator logged the case file into EVIDENCE himself - on a hidden, weighted shelf in the back. The record of this whole night is sitting in that room."},
	{"flag": "know_weight_trap", "title": "THE SPRING PLATE",
		"text": "The unlogged package in evidence sits on a weight-sensitive plate. Lifting it bare rings every bell in the building. It wants a stand-in - about a pound."},
	{"flag": "found_murder_weapon", "title": "THE PACKAGE - HIS BROTHER",
		"text": "The buried package is the CASE FILE my witness is testifying on. Mugshot on the front - and tucked behind it, a family photo. Two brothers at a lake. One is the defendant. The other is the CAPTAIN. That's the motive: the testimony buries his brother. Maybe I can take his GUN before it happens - crack his locker (his precious pooch's birthday might help) and end this once and for all."},
	{"flag": "captain_is_guilty", "title": "NOT A GUN - A DOORWAY",
		"text": "Cracked his locker expecting the gun. Instead the whole thing swings off the wall - a hidden passage running straight to the cells. He doesn't keep the weapon here. He keeps the ROUTE. That's how a man dies in a sealed cell. Now I have to stop him before midnight - he'll be here, at the passage, at the end."},
	{"flag": "taught_death_seen", "title": "WHAT I NEED TO NAIL HIM",
		"text": "Facing him alone gets me killed, and words don't stick to a captain. I need BOTH, in the same run: the PACKAGE from the evidence room in my hand, and a WITNESS he'd never expect - the rookie, hidden and listening. Talk to the ROOKIE and set the meet: locker room, 0:15. Then grab the evidence and be there at the end."},
	{"flag": "inmate_tip", "title": "THE WITNESS IS IN INTERROGATION",
		"text": "The prisoner saw them march my witness past not ten minutes ago - he's down in INTERROGATION right now, the whole night shift around him. Word inside: somebody CLOSE wanted him gone. He was safer behind bars. Go to interrogation."},
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
