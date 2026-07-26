extends CanvasLayer

# Rough dialogue box: black bottom bar, speaker name + line. Opening
# PAUSES the whole world - including the loop clock - and closing
# resumes it, so conversations never eat loop time.
#
# show_dialogue(lines) with lines = [{"speaker": String, "text": String}]
# Advance with E (the interact action).

signal opened
signal closed

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

## typewriter reveal speed; E snaps the line complete, E again advances
@export var chars_per_second := 45.0
@export var clack_path := "res://audio/sfx/mouse_click.mp3"

# each speaker gets their own name colour so you can tell voices apart at
# a glance. The dialogue layer sits ABOVE the mono dither, so these read
# in colour even in black-and-white mode. Any speaker not listed falls
# back to a deterministic colour hashed from their name.
const SPEAKER_COLORS := {
	"DETECTIVE": Color(0.85, 0.82, 0.7),
	"WITNESS": Color(0.55, 0.8, 1.0),
	"THE CAPTAIN": Color(1.0, 0.72, 0.42),
	"THE ROOKIE": Color(0.6, 0.95, 0.65),
	"RECEPTIONIST": Color(0.95, 0.65, 0.85),
	"EVIDENCE CLERK": Color(0.75, 0.7, 0.95),
	"INVESTIGATOR": Color(0.9, 0.55, 0.5),
	"NIGHT OFFICER": Color(0.95, 0.85, 0.5),
	"OFFICER": Color(0.55, 0.85, 0.85),
	"PATRON": Color(0.7, 0.72, 0.72),
	"PRISONER": Color(0.7, 0.72, 0.72),
	"THE CELL BLOCK": Color(0.7, 0.72, 0.72),
	"ALARM": Color(1.0, 0.4, 0.35),
	"CARD READER": Color(1.0, 0.4, 0.35),
}
## default name colour for narration / props / unlisted speakers
@export var default_speaker_color := Color(0.85, 0.82, 0.7)

var _lines: Array = []
var _index := 0
var _opened_frame := -1
var _flag_on_end := ""
var _reveal := 0.0
var _last_clack := 0

var _speaker := Label.new()
var _text := Label.new()
var _e_hint := Label.new()


func _ready() -> void:
	layer = 108
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialogue")
	# letterbox: a matching bar up top turns conversations into cinema
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.82)
	top.anchor_right = 1.0
	top.offset_bottom = 110.0
	add_child(top)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.anchor_top = 1.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top = -210.0
	add_child(bg)
	_speaker.add_theme_font_size_override("font_size", 26)
	_speaker.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_speaker.position = Vector2(70, 24)
	bg.add_child(_speaker)
	_text.add_theme_font_size_override("font_size", 32)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(70, 66)
	_text.size = Vector2(1700, 130)
	bg.add_child(_text)
	# the advance key, always visible in the corner of the letterbox -
	# dim while the line types, bright once it's waiting on the player
	_e_hint.text = "E ▸"
	_e_hint.add_theme_font_size_override("font_size", 26)
	_e_hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	_e_hint.anchor_left = 1.0
	_e_hint.anchor_right = 1.0
	_e_hint.anchor_top = 1.0
	_e_hint.anchor_bottom = 1.0
	_e_hint.offset_left = -120.0
	_e_hint.offset_right = -46.0
	_e_hint.offset_top = -52.0
	_e_hint.offset_bottom = -18.0
	bg.add_child(_e_hint)
	visible = false


func show_dialogue(lines: Array, flag_on_end: String = "") -> void:
	if lines.is_empty() or visible:
		return
	_lines = lines
	_index = 0
	_flag_on_end = flag_on_end
	_opened_frame = Engine.get_process_frames()
	visible = true
	get_tree().paused = true
	# the letterbox slides in with a breath, not a pop
	Sfx.play(self, "res://audio/sfx/journal.mp3", -20.0)
	opened.emit()
	_refresh()


func _refresh() -> void:
	var speaker := String(_lines[_index].get("speaker", ""))
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", _color_for(speaker))
	_text.text = String(_lines[_index].get("text", ""))
	_text.visible_characters = 0
	_reveal = 0.0
	_last_clack = 0


# a speaker's name colour: the curated map first, else a stable colour
# derived from the name so unknown speakers are still consistently tinted
func _color_for(speaker: String) -> Color:
	var key := speaker.to_upper()
	if SPEAKER_COLORS.has(key):
		return SPEAKER_COLORS[key]
	if speaker == "":
		return default_speaker_color
	var h := float(hash(key) % 360) / 360.0
	return Color.from_hsv(h, 0.45, 0.95)


func _process(_delta: float) -> void:
	if not visible:
		return
	# typewriter reveal with faint clacks
	var total := _text.text.length()
	if _text.visible_characters >= 0 and _text.visible_characters < total:
		_reveal += _delta * chars_per_second
		var n := mini(int(_reveal), total)
		if n != _text.visible_characters:
			_text.visible_characters = n
			if n - _last_clack >= 3:
				_last_clack = n
				Sfx.play(self, clack_path, -24.0)
	# the E cue breathes bright once the line is done typing
	var done: bool = _text.visible_characters < 0 \
			or _text.visible_characters >= total
	_e_hint.modulate.a = (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)) \
			if done else 0.35
	# the interact press that OPENED the dialogue must not also advance it
	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("interact"):
		# every press answers - completing a line or advancing to the next
		Sfx.play(self, "res://audio/sfx/hover.mp3", -12.0)
		# first press completes the line; the next advances
		if _text.visible_characters >= 0 and _text.visible_characters < total:
			_text.visible_characters = -1
			return
		_index += 1
		if _index >= _lines.size():
			visible = false
			get_tree().paused = false
			Sfx.play(self, "res://audio/sfx/journal.mp3", -22.0)
			if _flag_on_end != "":
				Flags.set_flag(_flag_on_end)
			closed.emit()
		else:
			_refresh()
