extends CanvasLayer

# Rough-draft pause menu: Esc opens/closes, pauses the loop while open.
# Entries sit on the left side, tilted for style. Two pages:
#   main:     CONTINUE / SETTINGS / RESTART LOOP / QUIT GAME
#   settings: BLACK & WHITE / DITHERING / FULLSCREEN / VOLUME / BACK
# Settings persist across loop restarts (statics survive the scene
# reload) but not across program runs yet - config file comes later.

static var bw_on := true
static var dither_on := true
static var fullscreen_on := true
static var volume_pct := 100
static var _restored := false

## title-screen mode: always visible, never pauses, shows the
## TITLE page (START / OPTIONS / QUIT) instead of the pause page
@export var title_mode := false

# gentle radius wobble - see _build_splash
var _box: VBoxContainer
var _mat: ShaderMaterial
var _splash: Node2D
var _splash_w := -1.0
var _hover_btn: Button
var _bw_btn: Button
var _dither_btn: Button
var _fs_btn: Button
var _vol_btn: Button
var _dim: ColorRect
var _click_audio: AudioStreamPlayer
var _minute_hand: Polygon2D
var _hand_t := 0.0
var _hand_step := -1
var _hand_reset_played := false

const Sfx := preload("res://scripts/game/sfx.gd")
const Flags := preload("res://scripts/game/flags.gd")
const HAND_TICK_TIME := 9.0
const HAND_WOBBLE_TIME := 0.7
const HAND_RETURN_TIME := 0.9


func _enter_tree() -> void:
	add_to_group("options_menu")


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rect: ColorRect = get_tree().get_first_node_in_group("dither_fx")
	if rect != null:
		_mat = rect.material
	if not _restored:
		# first boot: saved settings win; otherwise adopt what the scene
		# and window ship with
		_restored = true
		if not _load_settings():
			if _mat != null:
				bw_on = float(_mat.get_shader_parameter("mono")) > 0.5
				dither_on = float(_mat.get_shader_parameter("grain")) > 0.0
			fullscreen_on = DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
	_apply()

	_click_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/sfx/click.mp3"):
		_click_audio.stream = load("res://audio/sfx/click.mp3")
	_click_audio.volume_db = -16.0
	add_child(_click_audio)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the title scene should stay visible behind its menu
	_dim.visible = not title_mode
	add_child(_dim)

	_build_splash()
	_box = VBoxContainer.new()
	_box.position = Vector2(70, 420)
	_box.rotation_degrees = -8.0
	_box.add_theme_constant_override("separation", 18)
	add_child(_box)
	if title_mode:
		_show_page("title")
		visible = true
	else:
		_show_page("main")
		visible = false


func _show_page(page: String) -> void:
	_hover_btn = null
	if _splash != null:
		_splash.visible = false
	for c in _box.get_children():
		c.queue_free()
	_bw_btn = null
	_dither_btn = null
	_fs_btn = null
	_vol_btn = null
	if page == "title":
		# stacked typewriter title; the I in MIDNIGHT is a minute hand
		var tfont := load("res://fonts/Special_Elite/SpecialElite-Regular.ttf")
		var l1 := Label.new()
		l1.text = "THREE MINUTES"
		l1.add_theme_font_size_override("font_size", 72)
		l1.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95))
		if tfont != null:
			l1.add_theme_font_override("font", tfont)
		_box.add_child(l1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_box.add_child(row)
		for part in ["TO M", "DNIGHT"]:
			var l := Label.new()
			l.text = part
			l.add_theme_font_size_override("font_size", 96)
			l.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95))
			if tfont != null:
				l.add_theme_font_override("font", tfont)
			if part == "TO M":
				row.add_child(l)
			else:
				row.add_child(_make_clock_hand())
				row.add_child(l)
		_add_button("START", func() -> void:
			Sfx.play(self, "res://audio/sfx/start.mp3", -6.0)
			for c in _box.get_children():
				if c is Button:
					c.disabled = true
			var tw := create_tween()
			tw.tween_property(_box, "modulate:a", 0.0, 0.6)
			if _splash != null:
				tw.parallel().tween_property(_splash, "modulate:a", 0.0, 0.3)
			var scene := get_tree().current_scene
			if scene != null and scene.has_method("blackout"):
				await scene.blackout()
			else:
				await get_tree().create_timer(0.6).timeout
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/world.tscn"))
		_add_button("OPTIONS", func() -> void: _show_page("settings"))
		_add_button("QUIT", func() -> void:
			await get_tree().create_timer(0.2).timeout
			get_tree().quit())
	elif page == "main":
		_add_button("CONTINUE", _on_continue)
		_add_button("SETTINGS", func() -> void: _show_page("settings"))
		_add_button("CREDITS", _on_credits)
		# no restarting the opening night - the loop has to exist first
		if Flags.has_flag("intro_done"):
			_add_button("RESTART LOOP  (R)", _on_restart)
		_add_button("QUIT TO MENU", func() -> void:
			await get_tree().create_timer(0.2).timeout
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	else:
		_bw_btn = _add_button("", _on_bw)
		_dither_btn = _add_button("", _on_dither)
		_fs_btn = _add_button("", _on_fullscreen)
		_vol_btn = _add_button("", _on_volume)
		_add_button("BACK", func() -> void: _show_page("title" if title_mode else "main"))
	_refresh()


func _build_splash() -> void:
	# empty holder - the circle cluster is regenerated per hovered entry
	# so it always TILES the text width instead of stretching
	_splash = Node2D.new()
	_splash.visible = false
	add_child(_splash)


func _regen_splash(w: float) -> void:
	for c in _splash.get_children():
		c.queue_free()
	var col := Color(0.95, 0.95, 0.93)
	var radii := [46.0, 38.0, 50.0, 42.0, 36.0, 48.0, 40.0]
	var jitter := [2.0, -6.0, 6.0, -3.0]
	var x := -w * 0.5 + 26.0
	var i := 0
	while x < w * 0.5 - 14.0:
		var r: float = radii[i % radii.size()]
		var p := Polygon2D.new()
		p.polygon = _ngon(r, 8 if i % 3 == 1 else 10)
		p.color = col
		p.position = Vector2(x, jitter[i % 4])
		p.rotation = float(i) * 0.7
		_splash.add_child(p)
		x += r * 1.15
		i += 1
	for d in [
		[Vector2(w * 0.5 + 24, -14), 10.0], [Vector2(w * 0.5 + 48, 6), 6.0],
		[Vector2(-w * 0.5 - 24, 12), 8.0], [Vector2(-w * 0.5 - 44, -8), 5.0],
	]:
		var drop := Polygon2D.new()
		drop.polygon = _ngon(float(d[1]), 6)
		drop.color = col
		drop.position = d[0]
		_splash.add_child(drop)


func _make_clock_hand() -> Control:
	# the letter I as a pocket watch reading 11:57 - a small ring and
	# hour hand at the base, the minute hand rising as the letter's stem
	var c := Control.new()
	c.custom_minimum_size = Vector2(36, 100)
	var col := Color(0.97, 0.97, 0.95)
	var pivot_at := Vector2(18, 70)

	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for j in 17:
		pts.append(pivot_at + Vector2.from_angle(TAU * float(j) / 16.0) * 17.0)
	ring.points = pts
	ring.width = 3.0
	ring.default_color = col
	c.add_child(ring)

	var minute := Polygon2D.new()
	minute.polygon = PackedVector2Array([
		Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(1.2, -52), Vector2(0, -60), Vector2(-1.2, -52),
	])
	minute.color = col
	minute.position = pivot_at
	minute.rotation_degrees = -15.0
	c.add_child(minute)
	_minute_hand = minute

	var hour := Polygon2D.new()
	hour.polygon = PackedVector2Array([
		Vector2(-2, -2.4), Vector2(12, -1.6), Vector2(12, 1.6), Vector2(-2, 2.4),
	])
	hour.color = col
	hour.position = pivot_at
	hour.rotation_degrees = -100.0
	c.add_child(hour)

	var pivot := Polygon2D.new()
	pivot.polygon = _ngon(4.5, 8)
	pivot.color = col
	pivot.position = pivot_at
	c.add_child(pivot)
	return c


func _ngon(radius: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for j in sides:
		pts.append(Vector2.from_angle(TAU * float(j) / float(sides)) * radius)
	return pts


func _on_button_hover(b: Button) -> void:
	if _hover_btn != b:
		Sfx.play(self, "res://audio/sfx/hover.mp3", -12.0)
	_hover_btn = b
	_splash.visible = true


func _on_button_unhover() -> void:
	_hover_btn = null
	_splash.visible = false


func _process(_delta: float) -> void:
	# the title's minute hand: ticks toward midnight, strains with a
	# wobble, then winds smoothly back to the start - the loop in
	# miniature
	if title_mode and _minute_hand != null and is_instance_valid(_minute_hand):
		_hand_t += _delta
		var total := HAND_TICK_TIME + HAND_WOBBLE_TIME + HAND_RETURN_TIME
		if _hand_t >= total:
			_hand_t -= total
		var rot := -15.0
		if _hand_t < HAND_TICK_TIME:
			var stepf := floorf(_hand_t / HAND_TICK_TIME * 8.0)
			rot = lerpf(-15.0, -2.0, minf(stepf / 7.0, 1.0))
			var step := int(stepf)
			if step != _hand_step:
				_hand_step = step
				Sfx.play(self, "res://audio/ambient/tick.mp3" if step % 2 == 0 \
						else "res://audio/ambient/tock.mp3", -4.0)
			_hand_reset_played = false
		elif _hand_t < HAND_TICK_TIME + HAND_WOBBLE_TIME:
			# the mechanism strains before it gives
			if not _hand_reset_played:
				_hand_reset_played = true
				_hand_step = -1
				Sfx.play(self, "res://audio/sfx/clock_reset.mp3", -10.0)
			var w := (_hand_t - HAND_TICK_TIME) / HAND_WOBBLE_TIME
			rot = -2.0 + sin(w * 42.0) * 3.0 * w
		else:
			var r := (_hand_t - HAND_TICK_TIME - HAND_WOBBLE_TIME) / HAND_RETURN_TIME
			rot = lerpf(-2.0, -15.0, 1.0 - pow(1.0 - r, 3.0))
		_minute_hand.rotation_degrees = rot

	# follow the hovered button each frame - container layout settles a
	# frame after a page builds, so a one-shot position lands stale
	if _hover_btn != null and is_instance_valid(_hover_btn) and _splash.visible:
		# fit the splash to the TEXT, not the button - buttons stretch to
		# the column's width, text doesn't
		var f := _hover_btn.get_theme_font("font")
		var fs := _hover_btn.get_theme_font_size("font_size")
		var tw := f.get_string_size(_hover_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if absf(tw - _splash_w) > 1.0:
			_splash_w = tw
			_regen_splash(tw + 40.0)
		var center := _hover_btn.position + Vector2(tw * 0.5 + 10.0, _hover_btn.size.y * 0.5)
		_splash.position = _box.position + center.rotated(_box.rotation)
		_splash.rotation = _box.rotation
		# slow breathing pulse while hovered
		var pulse := 1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.006)
		_splash.scale = Vector2(1.0, 0.72) * pulse


func _add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 42)
	b.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.08, 0.1))
	b.add_theme_color_override("font_focus_color", Color(0.08, 0.08, 0.1))
	b.add_theme_color_override("font_pressed_color", Color(0.45, 0.1, 0.12))
	# kill every default button background box - otherwise clicking flashes a
	# light "pressed"/"hover" panel behind the text. Only the font colour reacts.
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	b.mouse_entered.connect(_on_button_hover.bind(b))
	b.focus_entered.connect(_on_button_hover.bind(b))
	b.mouse_exited.connect(_on_button_unhover)
	b.focus_exited.connect(_on_button_unhover)
	b.pressed.connect(func() -> void:
		if _click_audio.stream != null:
			_click_audio.play())
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _refresh() -> void:
	# is_instance_valid too, not just null - page switches free the settings
	# buttons but leave these vars pointing at the corpses, and F11 can call
	# this while the settings page isn't built
	if _bw_btn != null and is_instance_valid(_bw_btn):
		_bw_btn.text = "BLACK & WHITE:  %s" % ("ON" if bw_on else "OFF")
	if _dither_btn != null and is_instance_valid(_dither_btn):
		_dither_btn.text = "DITHERING:  %s" % ("ON" if dither_on else "OFF")
	if _fs_btn != null and is_instance_valid(_fs_btn):
		_fs_btn.text = "FULLSCREEN:  %s" % ("ON" if fullscreen_on else "OFF")
	if _vol_btn != null and is_instance_valid(_vol_btn):
		_vol_btn.text = "VOLUME:  %d%%" % volume_pct


func _apply() -> void:
	if _mat != null:
		_mat.set_shader_parameter("mono", 1.0 if bw_on else 0.0)
		# "off" also lifts the quantization, not just the grain
		_mat.set_shader_parameter("grain", 1.0 if dither_on else 0.0)
		_mat.set_shader_parameter("luma_levels", 32 if dither_on else 64)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume_pct / 100.0))
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_on \
			else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target:
		DisplayServer.window_set_mode(target)
	_save_settings()


# --- settings on disk (user://settings.cfg) - settings and NOTHING else;
# story progress deliberately dies with the session (the loop resets) ---

const SETTINGS_PATH := "user://settings.cfg"


static func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("display", "bw", bw_on)
	cf.set_value("display", "dither", dither_on)
	cf.set_value("display", "fullscreen", fullscreen_on)
	cf.set_value("audio", "volume_pct", volume_pct)
	cf.save(SETTINGS_PATH)


static func _load_settings() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return false
	bw_on = bool(cf.get_value("display", "bw", true))
	dither_on = bool(cf.get_value("display", "dither", true))
	fullscreen_on = bool(cf.get_value("display", "fullscreen", true))
	volume_pct = int(cf.get_value("audio", "volume_pct", 100))
	return true


func _input(event: InputEvent) -> void:
	# F11: quick fullscreen toggle, anywhere, menu open or not
	if event is InputEventKey and event.pressed and not event.is_echo() \
			and event.physical_keycode == KEY_F11:
		get_viewport().set_input_as_handled()
		_on_fullscreen()
		return
	if event is InputEventKey and event.pressed and not event.is_echo() \
			and event.physical_keycode == KEY_ESCAPE:
		if title_mode:
			get_viewport().set_input_as_handled()
			_show_page("title")
			return
		# conversations, the death fade, and the mirror peek own the
		# screen - no menu on top (and ESC belongs to whoever's active)
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null and dlg.visible:
			return
		var lose := get_tree().get_first_node_in_group("lose_screen")
		if lose != null and lose.is_active():
			return
		var peek := get_tree().get_first_node_in_group("active_peek")
		if peek != null:
			return
		# switch: if the journal is up, close it and open the menu
		var j := get_tree().get_first_node_in_group("journal")
		if j != null and j.visible and not visible:
			j._toggle()
		get_viewport().set_input_as_handled()
		_toggle_open()


func _toggle_open() -> void:
	if title_mode:
		return
	visible = not visible
	get_tree().paused = visible
	if visible:
		_show_page("main")


func _on_continue() -> void:
	_toggle_open()


func _on_bw() -> void:
	bw_on = not bw_on
	_apply()
	_refresh()


func _on_dither() -> void:
	dither_on = not dither_on
	_apply()
	_refresh()


func _on_fullscreen() -> void:
	fullscreen_on = not fullscreen_on
	_apply()
	_refresh()


func _on_volume() -> void:
	volume_pct -= 20
	if volume_pct < 0:
		volume_pct = 100
	_apply()
	_refresh()


func _on_credits() -> void:
	_toggle_open()
	var credits := get_tree().get_first_node_in_group("credits")
	if credits != null:
		credits.open()


func _on_restart() -> void:
	var clock := get_tree().get_first_node_in_group("loop_clock")
	if clock != null:
		clock.restart()
