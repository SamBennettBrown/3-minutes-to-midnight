extends Node

# LOOP 0 - the night it happened - plays ONCE per session; the flag
# `intro_done` survives restarts, so every later loop skips straight
# to the familiar start (rookie + coffee, witness already inside).
#
# The opening, in the BULLPEN, movement locked: fade in (no countdown -
# loop 0 has no timer) -> two stand-ins, the WITNESS and the CAPTAIN,
# are already in front of you. The witness thanks you and presses the
# family heirloom into your hand (the trinket, `bound_promise`); the
# captain says they need one final statement, and the pair walk off to
# interrogation and are removed. Movement unlocks with one task: talk to
# the front desk. You CAN'T leave by the door. At the desk the night
# tips over - a gunshot from the cells, the alarm, the block opens - and
# reaching the body in the cells is what finally ends loop 0.
#
# Also fades in from black at the start of EVERY loop.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")
const RigScene := preload("res://scenes/player/character_rig.tscn")

## DEV: tick to skip the whole loop-0 opening (plays as a normal loop)
@export var skip_intro := false
@export var rookie_path: NodePath
## after the eyes are fully open (blink + fade_in)
@export var monologue_at := 2.6
## the witness presses the heirloom into your hand
@export var trinket_at := 5.5
@export var rookie_delay := 12.0
@export var fade_in := 1.6
## how long the stand-ins take to walk off before they're removed
@export var standins_leave_time := 7.0

var _clock: Node
var _beat := 0
var _hint: Label
var _post_said := false
var _fake_witness: Node3D
var _fake_captain: Node3D
var _leave_at := -1.0


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
		# scene put them
	else:
		var r := get_node_or_null(rookie_path)
		if r != null:
			r.start_delay = rookie_delay
		# loop 0: movement locked through the stand-in beat; the front door
		# refuses on its own (exit_trigger), so no invisible blocks needed
		_lock_player.call_deferred(true)
		_spawn_standins.call_deferred()
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


## where the two stand-ins appear (bullpen world coords) - a spot the
## room camera clearly frames, a couple of metres from the spawn point.
## They face back toward the player.
@export var standin_witness_pos := Vector3(-1.2, 0, 3.6)
@export var standin_captain_pos := Vector3(0.2, 0, 3.6)

# stand-in witness + captain, placed in front of the player for the
# opening beat only. They are plain rig instances (no schedule script) so
# they never touch the real cast; freed once they've walked off.
func _spawn_standins() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	# face them back toward the player (or toward the spawn point)
	var look := p.global_position if p != null else Vector3(-1.5, 0, 1)
	_fake_witness = _make_standin(
			"SM_Chr_Criminal_Male_01",
			"res://POLYGON_Police_Station_SourceFiles_v3/SourceFiles/FBX/SM_Chr_Attach_Hair_05.fbx",
			standin_witness_pos, look)
	_fake_captain = _make_standin(
			"SM_Chr_Officer_Male_01",
			"res://POLYGON_Police_Station_SourceFiles_v3/SourceFiles/FBX/SM_Chr_Attach_Hair_01.fbx",
			standin_captain_pos, look)


func _make_standin(mesh: String, hair: String, pos: Vector3, look_at: Vector3) -> Node3D:
	var rig := RigScene.instantiate()
	rig.visible_mesh = mesh
	rig.hair_path = hair
	rig.start_clip = "idle"
	rig.strip_root_motion = true
	get_parent().add_child(rig)
	rig.global_position = pos
	var d: Vector3 = look_at - pos
	d.y = 0.0
	if d.length() > 0.01:
		rig.rotation.y = atan2(d.x, d.z)
	return rig


# walk the two stand-ins along the exit markers and free them once clear -
# "they head off to interrogation"
func _dismiss_standins() -> void:
	_leave_at = float(_clock.time) + standins_leave_time
	_exit_leg = 0
	_resolve_exit_path()
	for s in [_fake_witness, _fake_captain]:
		if is_instance_valid(s):
			s.play("walk")


# ease the player's heading to look at the midpoint of the two stand-ins
func _face_standins(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var mid := _fake_witness.global_position
	if is_instance_valid(_fake_captain):
		mid = (mid + _fake_captain.global_position) * 0.5
	var d: Vector3 = mid - p.global_position
	d.y = 0.0
	if d.length() < 0.3:
		return
	p.rotation.y = lerp_angle(p.rotation.y, atan2(d.x, d.z), delta * 4.0)


## the marker path the stand-ins follow off the bullpen floor - routed
## around the desks (WalkN -> RookiePost2 -> the hall-1 door) instead of a
## straight line that clips through the workstations
@export var standin_exit_spots: Array[String] = [
	"Bullpen/WalkN", "Bullpen/RookiePost2", "Bullpen/DoorHall1",
]

var _exit_path: Array = []
var _exit_leg := 0


func _resolve_exit_path() -> void:
	_exit_path.clear()
	for name in standin_exit_spots:
		var m := _find_spot(name)
		if m != null:
			_exit_path.append(m.global_position)


func _find_spot(spot: String) -> Node3D:
	var root := get_tree().root
	if "/" in spot:
		var parts := spot.split("/")
		var owner_node := root.find_child(parts[0], true, false)
		if owner_node != null:
			return owner_node.find_child(parts[1], true, false) as Node3D
		return null
	return root.find_child(spot, true, false) as Node3D


func _step_standins(delta: float) -> void:
	# walk them along the marker path, leg by leg, so they thread around the
	# desks instead of ploughing straight through them
	if _exit_path.is_empty():
		_resolve_exit_path()
	if _exit_leg >= _exit_path.size():
		return
	var target: Vector3 = _exit_path[_exit_leg]
	for s in [_fake_witness, _fake_captain]:
		if not is_instance_valid(s):
			continue
		var d: Vector3 = target - s.global_position
		d.y = 0.0
		if d.length() > 0.1:
			var dir := d.normalized()
			s.global_position += dir * 2.0 * delta
			s.rotation.y = lerp_angle(s.rotation.y, atan2(dir.x, dir.z), delta * 8.0)
	# advance to the next leg once the LEAD stand-in reaches this waypoint
	if is_instance_valid(_fake_witness):
		var lead := _fake_witness.global_position
		lead.y = 0.0
		if lead.distance_to(target) < 0.6:
			_exit_leg += 1


func _free_standins() -> void:
	for s in [_fake_witness, _fake_captain]:
		if is_instance_valid(s):
			s.queue_free()
	_fake_witness = null
	_fake_captain = null


func _process(_delta: float) -> void:
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	if Flags.has_flag("intro_done"):
		_post_intro(_delta)
		return
	# --- loop 0 ---
	# the stand-ins walk off after the heirloom beat, then get removed
	if _leave_at >= 0.0:
		_step_standins(_delta)
		if _clock.time >= _leave_at and _fake_witness != null:
			_free_standins()
			_after_standins()
	# turn the detective to face the two people standing in front of him
	# through the opening beat, so the conversation reads right
	if _beat <= 2 and is_instance_valid(_fake_witness):
		_face_standins(_delta)
	if get_tree().paused:
		return
	match _beat:
		0:
			# once the eyes are open, the whole opening exchange plays as ONE
			# unbroken conversation (monologue -> witness -> captain), so
			# there's no dead pause between the detective's line and theirs
			if _clock.time >= monologue_at:
				_beat = 2
				_say([
					{"speaker": "DETECTIVE", "text": "End of shift. The witness and the Captain - they've been waiting for me."},
					{"speaker": "WITNESS", "text": "Thank you, detective. For everything. I want you to have this - a family heirloom. A token. It's kept me... coming back."},
					{"speaker": "DETECTIVE", "text": "It's warm. Brass. ...Is it ticking?"},
					{"speaker": "THE CAPTAIN", "text": "We just need one final statement from him. Won't take long. Head home when you're done - go on."},
				], "bound_promise")
				# once that dialogue closes, send them off to interrogation
				var dlg := get_tree().get_first_node_in_group("dialogue")
				if dlg != null:
					dlg.closed.connect(_dismiss_standins, CONNECT_ONE_SHOT)
		3:
			# free to move; checking in with reception tips the night over
			if Flags.has_flag("talked_reception"):
				desk_checkin()
		4:
			# gunshot's gone off; reaching the cell block ends loop 0
			if _player_in_cells():
				cells_reached()


# --- the real loops (intro_done). loops 1 & 2 are the tutorial arc:
# loop 1 you think it was a bad night and try to go home (all other rooms
# sealed) - the front door restarts you; loop 2 the penny drops and you
# learn the goal. loop 3+ you're on your own with the countdown.
func _post_intro(_delta: float) -> void:
	if _post_said or _clock.time < 2.4 or get_tree().paused:
		return
	_post_said = true
	match Flags.loops:
		1:
			# still groggy - "just a rough night, go home"
			Flags.set_loop_flag("rooms_sealed")  # everything but the way out
			_say([
				{"speaker": "DETECTIVE", "text": "...What just happened? I was in the cells, and now - I'm back at my desk. Same coffee smell. I must be dead on my feet."},
				{"speaker": "DETECTIVE", "text": "Whatever this is, it can wait till morning. I'm going home."},
			])
			_set_task("Go home. Head out the front door.")
		2:
			# the reveal - the loop, the stakes, the goal, the clue
			_say([
				{"speaker": "DETECTIVE", "text": "Again. The door - and I'm BACK. This isn't exhaustion. Could it be... this heirloom? The thing he pressed into my hand?"},
				{"speaker": "DETECTIVE", "text": "He dies at midnight. Every time. And it drags me back to 11:57. Three minutes. That's all I get to save him."},
				{"speaker": "DETECTIVE", "text": "That note in his hand - a number. 57. A badge number, has to be. Start with the interrogation - that's where they took him."},
			], "know_loop")
			_set_task("Get to the interrogation room. Find out how he dies.")
		_:
			pass  # loop 3+: no hand-holding, the countdown speaks for itself


# called after the stand-ins are gone: hand the player control + the task
func _after_standins() -> void:
	_leave_at = -1.0
	_beat = 3
	_lock_player(false)
	_set_task("Check in with the front desk.")
	_set_hint("W · A · S · D — move. The reception desk is through the lobby.")


# the receptionist calls this when the player checks in at the desk - the
# player "clocks out and blabs a while", we FAST-FORWARD to midnight, and
# the night tips over: gunshot from the cells, alarm, the block opens
func desk_checkin() -> void:
	if _beat != 3:
		return
	_beat = 4
	_set_hint("")
	_lock_player(true)
	_set_task("")
	_time_skip_to_midnight()


# stylized skip to 12:00: the screen blurs, the wall clock races the last
# three minutes in a couple of seconds, a whoosh - then the shot lands
func _time_skip_to_midnight() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 114
	add_child(layer)
	var wash := ColorRect.new()
	wash.color = Color(0, 0, 0, 0)
	wash.anchor_right = 1.0
	wash.anchor_bottom = 1.0
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(wash)
	# a big centre clock that races 11:57 -> 12:00
	var big := Label.new()
	big.anchor_left = 0.5
	big.anchor_right = 0.5
	big.anchor_top = 0.5
	big.anchor_bottom = 0.5
	big.offset_left = -220.0
	big.offset_right = 220.0
	big.offset_top = -60.0
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 92)
	big.modulate = Color(1, 1, 1, 0)
	layer.add_child(big)
	var here := get_tree().get_first_node_in_group("player") as Node3D
	if here != null and ResourceLoader.exists("res://audio/sfx/rewind.mp3"):
		Sfx.play_at(here, "res://audio/sfx/rewind.mp3", -12.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# blur/dim in + clock fades up
	tw.parallel().tween_property(wash, "color:a", 0.7, 0.5)
	tw.parallel().tween_property(big, "modulate:a", 1.0, 0.5)
	# race the seconds 11:57:00 -> 12:00:00 over ~2s
	tw.tween_method(func(f: float) -> void:
		var secs := int(lerpf(0.0, 180.0, f))
		var total := 23 * 3600 + 57 * 60 + secs
		total %= 24 * 3600
		big.text = "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60],
		0.0, 1.0, 2.0)
	tw.tween_interval(0.15)
	tw.parallel().tween_property(big, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(wash, "color:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		layer.queue_free()
		_midnight_gunshot())


func _midnight_gunshot() -> void:
	# the shot + alarm land first, THEN the door blocks lift and the
	# detective reacts - so the "what was that?" reads after the bang
	Flags.set_loop_flag("cells_unlocked")
	Flags.set_flag("cells_unlocked")
	var pa := get_tree().get_first_node_in_group("intercom")
	if pa != null:
		pa.announce("Shots fired - cell block. All units.", 5.0)
	var here := get_tree().get_first_node_in_group("player") as Node3D
	if here != null:
		Sfx.play_at(here, "res://audio/sfx/gun_fire.mp3", -6.0)
		Sfx.play_at(here, "res://audio/ambient/alarm.mp3", -10.0, 6.0)
	# a beat, then the reaction line (dialogue pauses the world, so let the
	# gunshot ring out first)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		_lock_player(false)
		_set_task("A gunshot - from the cells. Get down there.")
		_say([
			{"speaker": "DETECTIVE", "text": "What was THAT? A gunshot - down the hall, the cell block. Nobody's supposed to be armed back there."},
		]))


# the cells room calls this when the player reaches the body - the
# detective finds the witness dead, prises the clue from his hand (the
# note with a badge number), and the night restarts: loop 0 is over
func cells_reached() -> void:
	if _beat != 4:
		return
	_beat = 5
	_say([
		{"speaker": "DETECTIVE", "text": "Cell two. The empty one. He's... he was ALIVE three minutes ago."},
		{"speaker": "DETECTIVE", "text": "Something in his hand. A scrap of paper, folded tight. A number scrawled on it - 57. A badge number?"},
		{"speaker": "DETECTIVE", "text": "The heirloom's gone ice cold. The night's... starting over. I can feel it."},
	], "found_note_57")
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null:
		dlg.closed.connect(_end_loop0, CONNECT_ONE_SHOT)
	else:
		_end_loop0()


func _end_loop0() -> void:
	Flags.set_flag("intro_done")
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		lose.play_lose()


# is the player standing in the cell block right now?
func _player_in_cells() -> bool:
	for r in get_tree().get_nodes_in_group("room"):
		if String(r.name) == "Cells" and r.has_method("contains_point"):
			var p := get_tree().get_first_node_in_group("player") as Node3D
			if p != null and r.contains_point(p.global_position, 0.0):
				return true
	return false


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
