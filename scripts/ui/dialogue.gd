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

# Each speaker gets their own name-tag color so it's clear at a glance who's
# talking. The player (the DETECTIVE) is reserved a vivid cyan that nothing
# else uses - instantly identifiable as "that's you." Named characters get
# hand-picked hues; anyone/anything not listed falls back to a deterministic
# color derived from the name, so every speaker is consistent and distinct
# without needing an entry here.
const PLAYER_SPEAKER := "DETECTIVE"
const PLAYER_COLOR := Color(0.31, 0.78, 1.0)  # vivid cyan - reserved for the player
const DEFAULT_SPEAKER_COLOR := Color(0.85, 0.82, 0.7)
const SPEAKER_COLORS := {
	"DETECTIVE": PLAYER_COLOR,
	"ROOKIE PETTY": Color(0.55, 0.85, 0.45),      # green
	"OFFICER DANIELS": Color(0.95, 0.62, 0.35),   # orange
	"OFFICER VANCE": Color(0.95, 0.78, 0.35),      # amber
	"OFFICER BELL": Color(0.72, 0.85, 0.4),        # lime
	"DETECTIVE ROSS": Color(0.7, 0.6, 0.95),       # violet
	"DETECTIVE VALE": Color(0.5, 0.72, 0.95),      # periwinkle
	"RECEPTIONIST": Color(0.95, 0.55, 0.75),       # pink
	"EVIDENCE CLERK": Color(0.6, 0.8, 0.8),        # teal
	"WITNESS": Color(0.95, 0.85, 0.5),             # pale gold
	"PATRON": Color(0.85, 0.7, 0.55),              # tan
	"PRISONER": Color(0.9, 0.5, 0.5),              # muted red
}

var _lines: Array = []
var _index := 0
var _opened_frame := -1
var _flag_on_end := ""
var _reveal := 0.0
var _last_clack := 0

var _speaker := Label.new()
var _text := Label.new()


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
	opened.emit()
	_refresh()


func _color_for(speaker_name: String) -> Color:
	if speaker_name == PLAYER_SPEAKER:
		return PLAYER_COLOR
	if SPEAKER_COLORS.has(speaker_name):
		return SPEAKER_COLORS[speaker_name]
	if speaker_name == "":
		return DEFAULT_SPEAKER_COLOR
	# Deterministic fallback: hash the name to a hue so unlisted speakers
	# (objects, notes, one-off characters) each get a stable, distinct color.
	# Kept clear of the player's cyan hue and comfortably readable on black.
	var h := speaker_name.hash()
	var hue := float(h % 1000) / 1000.0
	# nudge away from cyan (~0.52) so nothing masquerades as the player
	if absf(hue - 0.52) < 0.06:
		hue = fmod(hue + 0.2, 1.0)
	return Color.from_hsv(hue, 0.45, 0.95)


func _refresh() -> void:
	var speaker_name := String(_lines[_index].get("speaker", ""))
	_speaker.text = speaker_name
	_speaker.add_theme_color_override("font_color", _color_for(speaker_name))
	_text.text = String(_lines[_index].get("text", ""))
	_text.visible_characters = 0
	_reveal = 0.0
	_last_clack = 0


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
	# the interact press that OPENED the dialogue must not also advance it
	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("interact"):
		# first press completes the line; the next advances
		if _text.visible_characters >= 0 and _text.visible_characters < total:
			_text.visible_characters = -1
			return
		_index += 1
		if _index >= _lines.size():
			visible = false
			get_tree().paused = false
			if _flag_on_end != "":
				Flags.set_flag(_flag_on_end)
			closed.emit()
		else:
			_refresh()
