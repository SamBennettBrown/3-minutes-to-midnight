extends Node3D

# Title screen audio: the light-flicker buzz runs the whole time, with
# the sombre theme underneath it.

@export var blackout_hold := 0.9  # seconds of pure black before the game starts


func _ready() -> void:
	_play_loop("res://audio/ambient/light_flicker.mp3", -9.0)
	_play_loop("res://audio/bg/sombre.mp3", -20.0)


func _play_loop(path: String, volume_db: float) -> void:
	var stream = load(path)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	var a := AudioStreamPlayer.new()
	a.name = path.get_file().get_basename()
	a.stream = stream
	a.volume_db = volume_db
	add_child(a)
	a.play()


# START pressed: the lamp above the detective sputters harder and dies,
# the buzz cuts with it, the theme fades, and we hold on black.
func blackout() -> void:
	var lamp := $Lamp as SpotLight3D
	lamp.set_process(false)
	for a in get_children():
		if a is AudioStreamPlayer:
			create_tween().tween_property(a, "volume_db", -60.0, 1.2)
	var env: Environment = ($WorldEnvironment as WorldEnvironment).environment
	var fade := create_tween()
	fade.tween_property(env, "ambient_light_energy", 0.0, 1.0)
	fade.parallel().tween_property(env, "background_color", Color.BLACK, 1.0)
	var base := lamp.light_energy
	var tw := create_tween()
	for s in [[0.1, 0.07], [base, 0.1], [0.04, 0.06], [base * 0.7, 0.14],
			[0.02, 0.05], [base * 0.45, 0.11], [0.0, 0.1]]:
		tw.tween_property(lamp, "light_energy", s[0], s[1])
	await tw.finished
	var buzz := get_node_or_null("light_flicker") as AudioStreamPlayer
	if buzz != null:
		buzz.stop()
	await get_tree().create_timer(blackout_hold).timeout
