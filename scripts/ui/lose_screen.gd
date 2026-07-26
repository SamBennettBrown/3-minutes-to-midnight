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
# the rewind spectacle: while the rewind sfx plays under the black, the
# clock rips backward from 0:00 up to 3:00 with rings converging on it
var _fx: RewindFx
var _fx_clock: Label
var _fx_dur := 1.0
var _fx_time := -1.0


# The dial storm behind the rewinding clock: rings collapsing inward and a
# wheel of clock hands spinning BACKWARD - all driven off one 0..1 progress.
class RewindFx extends Control:
	var progress := 0.0
	const INK := Color(0.95, 0.95, 0.93)
	const BLOOD := Color(0.92, 0.32, 0.28)

	func _draw() -> void:
		var c := size * 0.5
		var max_r := c.length()
		# rings converging on the clock, staggered so there's always a few
		# mid-flight; they brighten and thicken as they close in
		for i in 7:
			var ph := fposmod(progress * 2.2 + float(i) / 7.0, 1.0)
			var r := (1.0 - ph) * max_r
			var col := Color(INK.r, INK.g, INK.b, ph * 0.5)
			draw_arc(c, maxf(r, 2.0), 0.0, TAU, 72, col, 2.0 + ph * 5.0)
		# a wheel of hands around the numbers, sweeping counter-clockwise -
		# time being dragged the wrong way. Every third hand runs blood-red.
		for i in 10:
			var ang := -progress * TAU * 2.5 + TAU * float(i) / 10.0
			var ln := 34.0 + 30.0 * sin(progress * TAU * 3.0 + float(i) * 1.7)
			var col := BLOOD if i % 3 == 0 else Color(INK.r, INK.g, INK.b, 0.7)
			var dir := Vector2(cos(ang), sin(ang))
			draw_line(c + dir * 190.0, c + dir * (190.0 + ln), col, 3.0)


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


func _process(delta: float) -> void:
	if _fx_time < 0.0:
		return
	_fx_time += delta
	if _fx_time >= _fx_dur:
		# done: clean up after ourselves - the death path reloads the scene
		# anyway, but the INTRO borrows this anim and plays on afterwards
		_fx_time = -1.0
		_fx.visible = false
		_fx_clock.visible = false
		return
	var p := clampf(_fx_time / _fx_dur, 0.0, 1.0)
	_fx.progress = p
	_fx.queue_redraw()
	# the readout accelerates like tape on rewind: slow first ticks, then a
	# blur up to 3:00
	var s := int(round(p * p * 180.0))
	var txt := "%d:%02d" % [s / 60, s % 60]
	if txt != _fx_clock.text:
		_fx_clock.text = txt
		# juice: every flip punches the clock a little bigger
		_fx_clock.pivot_offset = _fx_clock.size * 0.5
		_fx_clock.scale = Vector2(1.18, 1.18)
	_fx_clock.scale = _fx_clock.scale.lerp(Vector2.ONE, delta * 10.0)


func _start_rewind_fx(duration: float) -> void:
	if _fx == null:
		_fx = RewindFx.new()
		_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fx)
		_fx_clock = Label.new()
		_fx_clock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fx_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fx_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# the numbers must WIN against the dial storm behind them: huge, bold,
		# and a heavy black outline that carves the hands away around them
		var bold := "res://fonts/Crimson_Text/CrimsonText-Bold.ttf"
		if ResourceLoader.exists(bold):
			_fx_clock.add_theme_font_override("font", load(bold))
		_fx_clock.add_theme_font_size_override("font_size", 180)
		_fx_clock.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95))
		_fx_clock.add_theme_color_override("font_outline_color", Color.BLACK)
		_fx_clock.add_theme_constant_override("outline_size", 26)
		_fx_clock.text = "0:00"
		add_child(_fx_clock)
	# the teaching line hands the screen over to the rewind
	if _teach_label.modulate.a > 0.0:
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_teach_label, "modulate:a", 0.0, 0.25)
	_fx.visible = true
	_fx_clock.visible = true
	_fx_dur = duration
	_fx_time = 0.0


## The rewind spectacle (sfx + the clock ripping back up to 3:00) WITHOUT
## ending the loop. The intro plays this as the bridge from the monologue
## into the first run; play_lose routes through it for every reset.
func play_rewind(duration := 1.7) -> void:
	if ResourceLoader.exists(rewind_path):
		var rw := AudioStreamPlayer.new()
		rw.stream = load(rewind_path)
		rw.volume_db = rewind_volume_db
		add_child(rw)
		rw.play()
	_start_rewind_fx(duration)


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
	# the clock rips back to 3:00 over the rewind sound
	play_rewind(maxf(linger - 0.6, 0.1))
	await get_tree().create_timer(maxf(linger - 0.6, 0.1)).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	get_tree().paused = false
	get_tree().reload_current_scene()
