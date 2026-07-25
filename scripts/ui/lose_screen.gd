extends CanvasLayer

# The lose/restart screen: hard cut to black + gunshot, then the loop
# resets. EVERYTHING that ends a loop routes through here - dying, the
# clock running out, holding R, the menu's restart button. From any
# script:
#   get_tree().get_first_node_in_group("lose_screen").play_lose()
#
# set_darken(0..1) is the hold-R preview: the world dims toward black
# so the player sees the restart coming and can release to cancel.

## seconds of black (and gunshot) before the loop actually resets
@export var linger := 2.3
@export_file("*.wav", "*.ogg", "*.mp3") var sound_path := "res://audio/sfx/gun_fire.mp3"
@export var volume_db := -22.0
## the loop resetting under the black - the trinket's magic pulling the
## night back to its start
@export_file("*.wav", "*.ogg", "*.mp3") var rewind_path := "res://audio/sfx/magic.mp3"
@export var rewind_volume_db := -4.0
## a TAUGHT death (the captain shooting you when you confront him alone)
## holds this long on the black so the lesson can be read before reset
@export var teach_linger := 4.5

var _rect: ColorRect
var _audio: AudioStreamPlayer
var _teach_label: Label
var _active := false


func _enter_tree() -> void:
	add_to_group("lose_screen")


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = volume_db
	if ResourceLoader.exists(sound_path):
		_audio.stream = load(sound_path)
	add_child(_audio)
	# the teaching line for a taught death - hidden until play_lose gets one
	_teach_label = Label.new()
	_teach_label.anchor_left = 0.0
	_teach_label.anchor_right = 1.0
	_teach_label.anchor_top = 0.5
	_teach_label.offset_left = 120.0
	_teach_label.offset_right = -120.0
	_teach_label.offset_top = -80.0
	_teach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_teach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_teach_label.add_theme_font_size_override("font_size", 30)
	_teach_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.5))
	_teach_label.modulate.a = 0.0
	add_child(_teach_label)


func is_active() -> bool:
	return _active


func set_darken(amount: float) -> void:
	if _active:
		return
	_rect.color.a = clampf(amount, 0.0, 1.0) * 0.85


## Ends the loop. Pass a `teach_line` for a TAUGHT death (the captain
## shooting you alone): the line holds on the black so the lesson lands
## before the night resets. No line = a normal instant reset.
func play_lose(teach_line := "") -> void:
	if _active:
		return
	_active = true
	# muzzle flash, then black
	_rect.color = Color(1, 1, 1, 1)
	get_tree().paused = true
	if _audio.stream != null:
		_audio.play()
	await get_tree().create_timer(0.06).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_rect.color = Color(0, 0, 0, 1)
	# a taught death lingers with the lesson on screen before the rewind
	if teach_line != "":
		_teach_label.text = teach_line
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_teach_label, "modulate:a", 1.0, 0.6)
		await get_tree().create_timer(teach_linger).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return
	else:
		await get_tree().create_timer(0.54).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return
	if ResourceLoader.exists(rewind_path):
		var rw := AudioStreamPlayer.new()
		rw.stream = load(rewind_path)
		rw.volume_db = rewind_volume_db
		add_child(rw)
		rw.play()
	await get_tree().create_timer(maxf(linger - 0.6, 0.1)).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	get_tree().paused = false
	get_tree().reload_current_scene()
