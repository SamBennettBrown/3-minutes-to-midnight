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
@export var rewind_volume_db := -14.0

var _rect: ColorRect
var _audio: AudioStreamPlayer
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


func is_active() -> bool:
	return _active


func set_darken(amount: float) -> void:
	if _active:
		return
	_rect.color.a = clampf(amount, 0.0, 1.0) * 0.85


func play_lose() -> void:
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
