extends Node

# LOOP 0 - the night it happened - plays ONCE per session; the flag
# `intro_done` survives restarts, so every later loop skips straight
# to the familiar start (rookie + coffee, witness already inside).
#
# The opening, in the BULLPEN, movement locked until the coffee lands:
# fade in (no countdown shown yet) -> shift-end monologue -> the
# witness is escorted THROUGH the bullpen, brushing right past the
# detective - he slips the trinket - you turn and watch them go ->
# the rookie hustles over with the two-hour-old coffee -> movement
# unlocks, task: clock out, go home -> the front door in the lobby
# ends the night: the shot rings out from interrogation just as you
# reach it. Every restart's gunshot IS that gunshot.
#
# Also fades in from black at the start of EVERY loop.

const Flags := preload("res://scripts/game/flags.gd")

## DEV: tick to skip the whole loop-0 opening (plays as a normal loop)
@export var skip_intro := false
@export var witness_path: NodePath
@export var escort_paths: Array[NodePath] = []
@export var rookie_path: NodePath
## after the eyes are fully open (blink + fade_in)
@export var monologue_at := 2.6
## the witness brushes past the player (match the procession schedule)
@export var trinket_at := 8.0
## if the player never heads home, the night ends anyway
@export var fallback_shot_at := 90.0
@export var rookie_delay := 12.0
## where the witness stands (interrogation, near the mirror) in every
## loop after the first - close enough to talk to through the glass
@export var witness_room_pos := Vector3(0.5, 0, -23.6)
@export var fade_in := 1.6
## beat between reaching the front door and the gunshot
@export var shot_delay := 0.6
## loop 0: invisible blocks sealing the exits (door centers); gone once
## the coffee beat ends and the game hands you the clock-out task
@export var tutorial_door_blocks: Array[Vector3] = [Vector3(0, 1.5, 5)]

var _clock: Node
var _beat := 0
var _shot_at := -1.0
var _blocks: Array = []
var _hint: Label
var _post_said := false


func _enter_tree() -> void:
	add_to_group("intro_director")


func _ready() -> void:
	if skip_intro and not Flags.has_flag("intro_done"):
		Flags.set_flag("intro_done")
	# every loop wakes up: eyelids part, blink, then open fully
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 115
	add_child(fade_layer)
	var sz := get_viewport().get_visible_rect().size
	var top := ColorRect.new()
	top.color = Color.BLACK
	top.size = Vector2(sz.x, sz.y * 0.5)
	fade_layer.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	bottom.size = Vector2(sz.x, sz.y * 0.5)
	bottom.position = Vector2(0, sz.y * 0.5)
	fade_layer.add_child(bottom)
	var tw := create_tween()
	# keep opening even if a dialogue pauses the world mid-blink
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_eyelids.bind(top, bottom, sz), 0.0, 0.4, 0.35)
	tw.tween_method(_set_eyelids.bind(top, bottom, sz), 0.4, 0.06, 0.16)
	tw.tween_method(_set_eyelids.bind(top, bottom, sz), 0.06, 1.0, fade_in) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(fade_layer.queue_free)

	if Flags.has_flag("intro_done"):
		Flags.loops += 1
		# the interrogation cast (witness + escorts) is placed statically
		# inside the room now, so later loops leave them exactly where the
		# scene put them - just silence the witness's loop-0 walk barks
		var w := get_node_or_null(witness_path)
		if w != null:
			w.barks = []
	else:
		var r := get_node_or_null(rookie_path)
		if r != null:
			r.start_delay = rookie_delay
		# loop 0: no wandering off before the coffee - and no countdown
		_lock_player.call_deferred(true)
		for pos in tutorial_door_blocks:
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(2.6, 3.0, 0.5)
			cs.shape = box
			b.add_child(cs)
			add_child(b)
			b.global_position = pos
			_blocks.append(b)
		# tutorial hint line, bottom-left
		var hint_layer := CanvasLayer.new()
		hint_layer.layer = 102
		add_child(hint_layer)
		_hint = Label.new()
		_hint.anchor_top = 1.0
		_hint.anchor_bottom = 1.0
		_hint.position = Vector2(70, -110)
		_hint.add_theme_font_size_override("font_size", 26)
		_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
		_hint.visible = false
		hint_layer.add_child(_hint)


func _process(_delta: float) -> void:
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	if Flags.has_flag("intro_done"):
		# the first couple of REAL loops open with the detective reeling
		# (after the eyes have opened)
		if not _post_said and _clock.time >= 2.4 and not get_tree().paused:
			_post_said = true
			match Flags.loops:
				1:
					_say([
						{"speaker": "DETECTIVE", "text": "I- I was at the door. I heard the shot. The witness-"},
						{"speaker": "DETECTIVE", "text": "He's back in interrogation. The kid's carrying my coffee again. And the thing in my pocket is ticking louder."},
					])
				2:
					_say([
						{"speaker": "DETECTIVE", "text": "Again. AGAIN. Okay. Breathe. Same night. Same coffee. Same three minutes."},
						{"speaker": "DETECTIVE", "text": "Nobody else remembers. So it's on me. Help him live through this night."},
					])
		return
	# --- loop 0 ---
	if _shot_at >= 0.0:
		if _clock.time >= _shot_at:
			_shot()
		return
	# the detective can't help but watch the witness pass
	if _beat >= 1 and _beat <= 2:
		_watch_witness(_delta)
	if get_tree().paused:
		return
	match _beat:
		0:
			if _clock.time >= monologue_at:
				_beat = 1
				_say([{"speaker": "DETECTIVE",
					"text": "Three minutes to midnight. Three minutes and this shift is over. I can't wait."}])
		1:
			if _clock.time >= trinket_at:
				_beat = 2
				_say([
					{"speaker": "WITNESS", "text": "Please. Help me. You're the only one who-"},
					{"speaker": "DETECTIVE", "text": "Hey- what's this? He slipped something into my pocket. Small. Brass. Warm. ...Is it ticking?"},
				], "bound_promise")
		2:
			# the rookie's coffee dialogue ends by unlocking the player -
			# that's the moment the night hands you your one task
			var p := get_tree().get_first_node_in_group("player")
			if _clock.time > rookie_delay + 2.0 and p != null and not p.input_locked:
				_beat = 3
				for b in _blocks:
					if is_instance_valid(b):
						b.queue_free()
				_blocks.clear()
				var pa := get_tree().get_first_node_in_group("intercom")
				if pa != null:
					pa.announce("Day shift - midnight. Go home, people.", 5.0)
				_set_task("Clock out. Go home.")
				_set_hint("W · A · S · D — move. The front door is past the lobby.")
		3:
			if _clock.time >= fallback_shot_at:
				_fire_shot()


# the front door (exit_trigger) calls this when the player reaches it
func clock_out() -> void:
	if _beat >= 3 and _shot_at < 0.0:
		_fire_shot()


func _fire_shot() -> void:
	_set_hint("")
	_set_task("")
	if _clock != null:
		_shot_at = float(_clock.time) + shot_delay


func _shot() -> void:
	Flags.set_flag("intro_done")
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		lose.play_lose()


func _watch_witness(delta: float) -> void:
	var w := get_node_or_null(witness_path) as Node3D
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if w == null or p == null:
		return
	var d: Vector3 = w.global_position - p.global_position
	d.y = 0.0
	if d.length() < 0.5 or d.length() > 12.0:
		return
	p.rotation.y = lerp_angle(p.rotation.y, atan2(d.x, d.z), delta * 5.0)


func _lock_player(locked: bool) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.input_locked = locked


func _set_eyelids(openness: float, top: ColorRect, bottom: ColorRect, sz: Vector2) -> void:
	var h := sz.y * 0.5
	top.position.y = -h * openness
	bottom.position.y = h + h * openness


func _set_task(text: String) -> void:
	var obj := get_tree().get_first_node_in_group("objective")
	if obj != null:
		obj.set_task(text)


func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text
		_hint.visible = text != ""


func _say(lines: Array, flag := "") -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null:
		dlg.show_dialogue(lines, flag)
