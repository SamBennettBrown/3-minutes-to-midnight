extends Node

const Tuning := preload("res://scripts/game/tuning.gd")

# The loop: LOOP_LENGTH seconds that always unfold the same way, then
# the world restarts. R restarts immediately. Everything scheduled in
# the game - NPCs, events, doors - reads `time` (elapsed seconds) off
# this clock, never its own timers, so every loop replays exactly.
#
# The HUD shows a wall clock counting UP from 11:57:00 to midnight;
# `time` is still plain elapsed seconds, only the display is offset.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

## seconds per loop
@export var loop_length := Tuning.LOOP_LENGTH
## wall-clock time the loop starts at (counts up to midnight)
@export var start_hour := 23
@export var start_minute := 57
## hold R this long to restart; the screen darkens while held so a
## stray tap can't reset the run
@export var restart_hold := 3.0
## the countdown becomes audible at the end: tick-tock swells over the
## final 30 seconds, heartbeats layer in over the final 15
@export var tick_swell_start_db := -26.0
@export var tick_swell_end_db := -8.0
@export var heart_swell_start_db := -20.0
@export var heart_swell_end_db := -6.0

var time := 0.0

var _label := Label.new()
var _r_held := 0.0
var _prev_left := -1


func _enter_tree() -> void:
	# group membership set here, not _ready, so siblings that ready
	# earlier can still find the clock
	add_to_group("loop_clock")
	# a new loop starts: whatever you were HOLDING is back where it was
	Flags.clear_loop_flags()


func _ready() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 101
	add_child(hud)
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -320.0
	_label.offset_top = 14.0
	_label.offset_right = -20.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 56)
	hud.add_child(_label)


func _process(delta: float) -> void:
	time += delta
	if time >= loop_length:
		restart()
		return
	if Input.is_action_pressed("restart") and Flags.has_flag("intro_done"):
		_r_held += delta
		_set_darken(_r_held / restart_hold)
		if _r_held >= restart_hold:
			_r_held = 0.0
			restart()
			return
	elif _r_held > 0.0:
		# backed out of the restart: the hammer falls on an empty chamber
		if _r_held > 0.4:
			Sfx.play(self, "res://audio/sfx/empty_gun.mp3", -10.0)
		_r_held = 0.0
		_set_darken(0.0)
	var left := int(ceil(loop_length - time))
	# wall clock counting up: 11:57:00 + elapsed, shown as HH:MM:SS
	var total_s := int(start_hour) * 3600 + int(start_minute) * 60 + int(time)
	total_s %= 24 * 3600
	_label.text = "%02d:%02d:%02d" % [total_s / 3600, (total_s / 60) % 60, total_s % 60]
	# the clock only becomes real after the first gunshot (the opening
	# night runs to its own scripted end)
	_label.visible = Flags.has_flag("intro_done")
	_heartbeat(left, delta)
	_tension_ramp()


func _heartbeat(left: int, delta: float) -> void:
	# final minute: the countdown swells on each second; final 30: an
	# audible tick under everything
	_label.pivot_offset = _label.size * 0.5
	_label.scale = _label.scale.lerp(Vector2.ONE, delta * 6.0)
	if left == _prev_left:
		return
	_prev_left = left
	if not Flags.has_flag("intro_done"):
		return
	if left <= 60:
		_label.scale = Vector2(1.3, 1.3)
	if left <= 30:
		var swell := lerpf(tick_swell_start_db, tick_swell_end_db, 1.0 - float(left) / 30.0)
		Sfx.play(self, "res://audio/ambient/tick.mp3" if left % 2 == 0 \
				else "res://audio/ambient/tock.mp3", swell)
	if left <= 15:
		var hswell := lerpf(heart_swell_start_db, heart_swell_end_db, 1.0 - float(left) / 15.0)
		Sfx.play(self, "res://audio/sfx/heartbeat1.mp3" if left % 2 == 0 \
				else "res://audio/sfx/heartbeat2.mp3", hswell)


func _tension_ramp() -> void:
	# the film degrades in the last 30 seconds: grain climbs, the
	# posterization tightens - the trinket running out of patience
	if not Flags.has_flag("intro_done"):
		return
	var rect: ColorRect = get_tree().get_first_node_in_group("dither_fx")
	if rect == null or rect.material == null:
		return
	var mat: ShaderMaterial = rect.material
	if float(mat.get_shader_parameter("grain")) <= 0.0:
		return  # player turned dithering off - respect it
	var t := clampf(1.0 - (loop_length - time) / 30.0, 0.0, 1.0)
	mat.set_shader_parameter("shadow_grain", lerpf(0.5, 2.6, t))
	mat.set_shader_parameter("luma_levels", int(round(lerpf(32.0, 18.0, t))))


func _set_darken(amount: float) -> void:
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		lose.set_darken(amount)


func restart() -> void:
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		lose.play_lose()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()
