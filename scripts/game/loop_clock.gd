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
## hold R this long to restart; the screen darkens, the trinket TICKS and a
## big REWINDING banner ramps in while held - fast, but a stray tap still
## can't reset the run
@export var restart_hold := 1.4
## the countdown becomes audible at the end: tick-tock swells over the
## final 30 seconds, heartbeats layer in over the final 15
@export var tick_swell_start_db := -26.0
@export var tick_swell_end_db := -8.0
@export var heart_swell_start_db := -20.0
@export var heart_swell_end_db := -6.0

var time := 0.0
## when the endgame intercept fires, the clock FREEZES here - the night
## never reaches 0:00, so the murder never happens. The endgame director
## sets this; nothing else touches it.
var frozen := false

var _label := Label.new()
var _r_held := 0.0
var _r_label: Label
var _r_tick := 0.0
var _r_tock := false
var _prev_left := -1
var _dlg: Node
# the final-minute drone: static that swells and sharpens as 0:00 nears
var _drone: AudioStreamPlayer


func _enter_tree() -> void:
	# group membership set here, not _ready, so siblings that ready
	# earlier can still find the clock
	add_to_group("loop_clock")
	# a new loop starts: whatever you were HOLDING is back where it was
	Flags.clear_loop_flags()
	# every scene load is a fresh loop (first boot = loop 1). Some beats
	# escalate with the count - e.g. the rookie closes in faster each time.
	Flags.loops += 1


func _ready() -> void:
	var hud := CanvasLayer.new()
	# ABOVE the intercom banner (102), BELOW the pause menu (105) so the
	# menu's dim still covers it, and below case-file toasts (104)
	hud.layer = 103
	add_child(hud)
	# the countdown owns the top-centre of the screen - big, so it's the
	# thing you can't look away from
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.offset_top = 18.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 96)
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
	# a dark outline lifts it off whatever ends up underneath
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 12)
	hud.add_child(_label)
	# the hold-R banner: big, centred, blood-warm - ramps in over the darken
	# while the trinket ticks, so a restart never sneaks up on you
	_r_label = Label.new()
	_r_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_r_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_r_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_r_label.text = "REWINDING THE NIGHT"
	_r_label.add_theme_font_size_override("font_size", 64)
	_r_label.add_theme_color_override("font_color", Color(0.92, 0.32, 0.28))
	_r_label.modulate.a = 0.0
	hud.add_child(_r_label)


func _process(delta: float) -> void:
	# the countdown doesn't burn time during the OPENING MONOLOGUE only - it
	# holds until the intro hands over control (bound_promise). After that the
	# 3:00 runs continuously EVERY loop, even while other beats lock the
	# player's MOVEMENT (the observation peek, the rookie's approach) - those
	# are gameplay, and the loop must keep counting down through them.
	var live: bool = Flags.has_flag("bound_promise")
	if not live:
		_label.visible = false
		return
	# hide the countdown while a conversation has the screen (letterboxed
	# dialogue reads as a cutaway - the clock over it breaks the frame). The
	# tree is paused during dialogue so we won't run again until it closes;
	# hiding happens on the OPENED signal, and _process restores after.
	if _dlg == null:
		_dlg = get_tree().get_first_node_in_group("dialogue")
		if _dlg != null:
			_dlg.opened.connect(func() -> void: _label.visible = false)
	# the session stopwatch, for the win credits - all live play counts,
	# including the frozen confrontation
	Flags.playtime += delta
	# the endgame caught the killer: the night is held open, the countdown
	# stops where it stands (still shown, still able to hold-R to restart).
	if frozen:
		var rem_f: float = maxf(loop_length - time, 0.0)
		_label.text = "%d:%02d" % [int(rem_f) / 60, int(rem_f) % 60]
		_label.visible = true
		# the world holds its breath - the drone dies with the freeze
		if _drone != null and _drone.playing:
			_drone.stop()
		return
	time += delta
	if time >= loop_length:
		restart()
		return
	if Input.is_action_pressed("restart"):
		var prog := _r_held / restart_hold
		_r_held += delta
		_set_darken(prog)
		# the banner ramps in ahead of the darken so it reads immediately
		_r_label.modulate.a = clampf(prog * 1.6, 0.0, 1.0)
		# the trinket ticks faster and faster as the rewind takes hold
		_r_tick -= delta
		if _r_tick <= 0.0:
			_r_tick = lerpf(0.24, 0.08, prog)
			_r_tock = not _r_tock
			Sfx.play(self, "res://audio/ambient/tock.mp3" if _r_tock else "res://audio/ambient/tick.mp3", -6.0)
		if _r_held >= restart_hold:
			_r_held = 0.0
			_r_label.modulate.a = 0.0
			restart()
			return
	elif _r_held > 0.0:
		# backed out of the restart: the hammer falls on an empty chamber
		if _r_held > 0.3:
			Sfx.play(self, "res://audio/sfx/empty_gun.mp3", -10.0)
		_r_held = 0.0
		_r_tick = 0.0
		_r_label.modulate.a = 0.0
		_set_darken(0.0)
	var left := int(ceil(loop_length - time))
	# COUNTDOWN to midnight: 3:00 -> 0:00. The theme is the clock running
	# out, so the HUD counts DOWN the time you have left.
	var rem: float = maxf(loop_length - time, 0.0)
	_label.text = "%d:%02d" % [int(rem) / 60, int(rem) % 60]
	_label.visible = true
	_heartbeat(left, delta)
	_tension_ramp()
	_drone_ramp(rem)


# a low bed of static that rises through the final minute - by 0:10 it's
# a hiss right under everything. Dies with the scene on restart; the
# endgame freeze stops it cold (the world holds its breath instead).
func _drone_ramp(rem: float) -> void:
	if not Flags.has_flag("intro_done"):
		return
	if rem > 60.0:
		if _drone != null and _drone.playing:
			_drone.stop()
		return
	if _drone == null:
		if not ResourceLoader.exists("res://audio/ambient/static.wav"):
			return
		_drone = AudioStreamPlayer.new()
		var s: AudioStream = load("res://audio/ambient/static.wav")
		if s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_drone.stream = s
		add_child(_drone)
	if not _drone.playing:
		_drone.play()
	var t := 1.0 - rem / 60.0
	_drone.volume_db = lerpf(-44.0, -16.0, t)
	_drone.pitch_scale = lerpf(0.55, 0.95, t)


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
	if left <= 30:
		# the pops sharpen as the night closes in
		_label.scale = Vector2(1.45, 1.45)
	elif left <= 60:
		_label.scale = Vector2(1.2, 1.2)
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
