extends SpotLight3D

# A tired station lamp: uneven hum-flicker with the occasional hard
# dropout, and a crackle of static when it cuts out. Layered sines -
# cheap, deterministic, never settles.

@export var base_energy := 5.0
@export var flicker_depth := 0.4
@export var flicker_speed := 11.0
@export var dropout_volume_db := -14.0
@export_file("*.wav", "*.mp3") var dropout_sound := "res://audio/ambient/light_flicker.mp3"

var _t := 0.0
var _was_out := false
var _noise: AudioStreamPlayer3D


func _ready() -> void:
	_noise = AudioStreamPlayer3D.new()
	if ResourceLoader.exists(dropout_sound):
		_noise.stream = load(dropout_sound)
	_noise.volume_db = dropout_volume_db
	_noise.max_distance = 12.0
	add_child(_noise)


func _process(delta: float) -> void:
	_t += delta
	var e := 1.0 - flicker_depth * 0.5 + flicker_depth * 0.5 * sin(_t * flicker_speed) * sin(_t * 4.7)
	var out := sin(_t * 3.1) * sin(_t * 7.7) > 0.93
	if out:
		e = 0.12
	if out and not _was_out and _noise.stream != null:
		_noise.play()
	elif not out and _was_out:
		_noise.stop()
	_was_out = out
	light_energy = base_energy * e
