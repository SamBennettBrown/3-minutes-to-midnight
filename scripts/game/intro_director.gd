extends Node

# The opening. Loops 0 & 1 and all their scripted special-casing are GONE
# (see docs/DESIGN.md). Every loop is the same core loop from frame one.
#
# The FIRST time the game runs this session it plays a short black-screen
# monologue over a gunshot, hands the detective the heirloom + his first
# lead, then gives control. `intro_done` marks it played; it survives loop
# restarts (static flag) so the monologue never repeats, and the countdown
# just begins each loop after. A quick fade-up from black opens every loop.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

## the monologue, shown one line at a time on black. First line lands on
## the gunshot.
@export var monologue := [
	"That sound again.",
	"Three minutes to midnight. My shift's almost over - but no matter what I do, it's always the same.",
	"I got my witness his justice, the protection he needed. He was so thankful he pressed this into my hand. A family heirloom.",
	"Then it happens. He's killed in the cell block - and there's no one in there but a prisoner with no gun.",
	"He's walked in, everyone leaves. A minute later he's dead. And when the clock strikes twelve, it's 11:57 again.",
	"I could throw this thing in the trash and be done with it. But this is the job.",
	"So. Here we go again.",
]
@export var fade := 0.6
## the shortest a line stays up (after fading in) before E can advance it,
## so a held/mashed key can't skip the whole monologue at once
@export var min_read := 0.5
## flags the intro grants once the monologue finishes
@export var grants_flag := "bound_promise"
@export var lead_flag := "know_impossible_death"

var _layer: CanvasLayer
var _black: ColorRect
var _label: Label
var _hint: Label
var _line := 0
var _t := 0.0
var _playing := false
var _fading_out := false
# ESC-skip stays LOCKED until the opening gunshot has fully played out -
# the shot is the hook, nobody gets to cut it off
var _elapsed := 0.0
var _skip_at := 0.0


func _enter_tree() -> void:
	add_to_group("intro_director")


func _ready() -> void:
	# the monologue must keep fading even if something pauses the tree (a
	# dialogue box, a menu) - otherwise the intro freezes mid-line.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 118
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.anchor_right = 1.0
	_black.anchor_bottom = 1.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)

	if Flags.has_flag("intro_done"):
		# a later loop: hold the black for a beat with a film-slate stamp
		# ("NIGHT 14 - 11:57 PM"), then lift the wash and let the loop run
		_show_slate()
		return

	# first run this session: the scripted monologue
	Flags.set_flag("intro_done")
	_label = Label.new()
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.5
	_label.offset_left = 120.0
	_label.offset_right = -120.0
	_label.offset_top = -80.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	_label.modulate.a = 0.0
	_layer.add_child(_label)
	# a quiet "E to continue" prompt near the bottom
	_hint = Label.new()
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -80.0
	_hint.offset_bottom = -40.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.78))
	_hint.text = "E to continue"
	_hint.modulate.a = 0.0
	_layer.add_child(_hint)
	_playing = true
	# claim ESC while the monologue plays - the pause menu checks this group
	# before opening, so ESC skips the intro instead of raising the menu
	add_to_group("active_peek")
	_lock_player.call_deferred(true)
	# the gunshot that opens the night; skipping unlocks only once it's rung out
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null and ResourceLoader.exists("res://audio/sfx/gun_fire.mp3"):
		Sfx.play(self, "res://audio/sfx/gun_fire.mp3", -6.0)
		var shot := load("res://audio/sfx/gun_fire.mp3") as AudioStream
		if shot != null:
			_skip_at = shot.get_length()
	_show_line()


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	# once the shot has rung out, the hint starts offering the skip
	if _hint != null and _skip_at > 0.0 and _elapsed >= _skip_at:
		_hint.text = "E to continue   ·   ESC to skip"
		_skip_at = 0.0
	_t += delta
	# fade the line IN, then HOLD until the player presses E to advance
	# (with a short minimum so a held key can't skip the whole thing).
	if _fading_out:
		_label.modulate.a = maxf(1.0 - _t / fade, 0.0)
		if _t >= fade:
			_advance()
		return
	if _t < fade:
		_label.modulate.a = _t / fade
	else:
		_label.modulate.a = 1.0
		# show the hint once the line is readable
		if _hint != null and _t >= fade + 0.4:
			_hint.modulate.a = minf((_t - fade - 0.4) / 0.4, 0.55)
		if _t >= fade + min_read and Input.is_action_just_pressed("interact"):
			_fading_out = true
			_t = 0.0
			if _hint != null:
				_hint.modulate.a = 0.0


func _advance() -> void:
	_line += 1
	_fading_out = false
	_t = 0.0
	if _line >= monologue.size():
		_finish()
	else:
		_show_line()


func _show_line() -> void:
	_label.text = String(monologue[_line])
	_label.modulate.a = 0.0
	_t = 0.0
	_fading_out = false


func _input(event: InputEvent) -> void:
	# ESC skips the whole monologue (first run only; it never replays)
	if not _playing:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		# swallow ESC (so the pause menu can't grab it) but refuse the skip
		# until the opening gunshot has finished
		if _elapsed < _skip_at:
			return
		_finish()


func _finish() -> void:
	_playing = false
	if is_in_group("active_peek"):
		remove_from_group("active_peek")
	if _label != null:
		_label.queue_free()
	if _hint != null:
		_hint.queue_free()
	# the trinket winds the night back for the FIRST time: the rewind
	# spectacle plays over the black as the bridge into the loop
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null and lose.has_method("play_rewind"):
		lose.play_rewind(1.7)
		await get_tree().create_timer(1.7).timeout
		if not is_inside_tree():
			return
	# lift the black, hand control back, and only THEN raise the flags that
	# wake the world. ORDER MATTERS: the rookie's opening beat starts the
	# moment bound_promise exists and re-locks the player - raising the flag
	# before this fade meant our own unlock STOMPED his lock 0.6s later, so
	# the player walked free through the beat on the very first loop.
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_black, "color:a", 0.0, fade)
	tw.tween_callback(func() -> void:
		_lock_player(false)
		if grants_flag != "":
			Flags.set_flag(grants_flag)
		if lead_flag != "":
			Flags.set_flag(lead_flag))


func _lock_player(locked: bool) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.input_locked = locked


# the film slate: every restarted night is numbered, stamped on the black
# before the fade-up - the count is FELT, and every gif explains itself
func _show_slate() -> void:
	var slate := Label.new()
	slate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slate.text = "NIGHT %d  —  11:57 PM" % Flags.loops
	var tw_font := "res://fonts/Special_Elite/SpecialElite-Regular.ttf"
	if ResourceLoader.exists(tw_font):
		slate.add_theme_font_override("font", load(tw_font))
	slate.add_theme_font_size_override("font_size", 44)
	slate.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	_layer.add_child(slate)
	Sfx.play(self, "res://audio/sfx/click.mp3", -10.0)
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(slate, "modulate:a", 0.0, fade * 0.5)
	tw.parallel().tween_property(_black, "color:a", 0.0, fade)
	tw.tween_callback(slate.queue_free)
