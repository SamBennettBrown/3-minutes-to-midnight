extends CanvasLayer

# The station PA: scheduled announcements on the loop clock. A banner
# strip at the top of the screen - NEVER pauses the game; the world
# keeps moving under it. Opens with a static crackle.

@export var announcements: Array = [
	{"t": 20.0, "text": "Shift change in five minutes. Evidence lockup closes at quarter to.", "dur": 6.0},
	{"t": 70.0, "text": "Detective, the chief wants your report on his desk. Today.", "dur": 6.0},
]
@export var crackle_volume_db := -16.0

var _i := 0
var _timer := 0.0
var _clock: Node
var _strip: ColorRect
var _label: Label
var _audio: AudioStreamPlayer


func _enter_tree() -> void:
	add_to_group("intercom")


func announce(text: String, dur := 5.0) -> void:
	_show({"text": text, "dur": dur})


func _ready() -> void:
	layer = 102
	_strip = ColorRect.new()
	_strip.color = Color(0, 0, 0, 0.65)
	_strip.anchor_right = 1.0
	_strip.offset_bottom = 60.0
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.visible = false
	add_child(_strip)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_label.position = Vector2(70, 14)
	_strip.add_child(_label)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = crackle_volume_db
	if ResourceLoader.exists("res://audio/ambient/static.wav"):
		_audio.stream = load("res://audio/ambient/static.wav")
	add_child(_audio)


func _process(delta: float) -> void:
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		if _clock == null:
			return
	while _i < announcements.size() and _clock.time >= float(announcements[_i].get("t", 1e9)):
		_show(announcements[_i])
		_i += 1
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_strip.visible = false


func _show(a: Dictionary) -> void:
	_label.text = "INTERCOM //  " + String(a.get("text", ""))
	_strip.visible = true
	_timer = float(a.get("dur", 5.0))
	_audio.play()
