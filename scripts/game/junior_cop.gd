@tool
extends "res://scripts/player/player.gd"

# The junior cop: opens EVERY loop by bringing the detective his coffee
# and bugging him. He reads as comic relief - he is actually the final
# key to the whole puzzle.
#
# Loop opening beat: player input locks, he walks in from the doorway,
# dialogue auto-opens (variant picked by story flags - LAST entry whose
# flag is set wins, empty flag = always eligible), then the player is
# freed and he wanders to his post. He stays talkable afterwards and
# always speaks his newest variant.

@export var spawn_pos := Vector3(0, 0, -4.6)
@export var post_pos := Vector3(2.6, 0, -3.4)
@export var approach_speed := 1.9
@export var approach_distance := 1.3
## loop-clock time at which the approach starts (0 = from the top of the loop)
@export var start_delay := 0.0
## the room the rookie belongs to (his approach is CLAMPED to it, so he
## never chases the player through a wall into another room). Empty = the
## room named "Bullpen".
@export var home_room_path: NodePath
## how close he keeps while following you on the final run (legacy - the
## rookie no longer follows; kept so old scene overrides still load)
@export var follow_distance := 1.6
## the room he hides in for the ambush, and the marker he tucks behind.
## He waits OUTSIDE the locker room door - out of the captain's sight -
## and only steps in when the endgame calls step_in() for his line.
@export var stage_room_name := "LockerRoom"
@export var stage_spot_name := "Hall2/DoorLocker"
## where the dramatic entrance lands - just inside the locker room door
@export var step_in_spot := "LockerRoom/Door"
## loop time he leaves his post to make the meet ("locker room, 0:15") -
## early enough to be hidden there before the clock reads 0:15 (t165)
@export var stage_go_time := 150.0

const Tuning := preload("res://scripts/game/tuning.gd")
const CoffeeSfx := preload("res://scripts/game/sfx.gd")
var _state := "approach"
var _player_body: Node3D
var _dialogue_ui: Node
var _clock: Node
var _locked := false
var _intro_opened := false
var _talk_wait := 0.0
var _approach_wait := 0.0
var _home_room: Node3D


func _ready() -> void:
	# TWO separate pools:
	#  - the AUTO-INTRO beat (freezes the player each loop) rotates through
	#    short coffee exchanges - see _pick_intro(). Flavour only.
	#  - dialogue_variants (below) is what you get when you WALK UP and talk
	#    to him: he's the HINT SYSTEM. He reads your progress (journal flags)
	#    and points you at the NEXT thing you don't have. Last match wins, so
	#    order = the case chain. The "anything you need?" gag pays off in the
	#    recruit beat.
	if dialogue_variants.is_empty():
		dialogue_variants = [
			# --- no leads yet -> the cells / the prisoner. He knows NOTHING
			# about any murder - only the detective loops. He just gossips.
			{"lines": [
				{"speaker": "THE ROOKIE", "text": "Whole station's wound up about the witness tonight. They've got the cell block down Hall 2 prepped and everything."},
				{"speaker": "DETECTIVE", "text": "The cell block. ...Yeah. I know how tonight goes."},
				{"speaker": "THE ROOKIE", "text": "There's another guest down there too - talkative type, opinions on everybody. And hey, if you need anything - anything - I'm right here."},
			]},
			# --- prisoner said interrogation -> point at the observation glass ---
			{"flag": "inmate_tip", "lines": [
				{"speaker": "THE ROOKIE", "text": "Interrogation's sealed tight - NO ENTRY, captain's orders. But, uh... the observation room's right next door, off Hall 1. Two-way glass."},
				{"speaker": "DETECTIVE", "text": "You didn't tell me that."},
				{"speaker": "THE ROOKIE", "text": "Tell you what? I didn't say anything. ...Need anything else, you know where I am."},
			]},
			# --- overheard the evidence tip -> a nudge toward the front desk ---
			{"flag": "heard_evidence_tip", "lines": [
				{"speaker": "THE ROOKIE", "text": "You've got that locked-door look, detective."},
				{"speaker": "THE ROOKIE", "text": "...All I'll say is, the receptionist sees everything that crosses that front desk. Well. ALMOST everything."},
				{"speaker": "DETECTIVE", "text": "Kid, you might actually be useful."},
			]},
			# --- knows the weight trap -> the vending machine ---
			{"flag": "know_weight_trap", "lines": [
				{"speaker": "THE ROOKIE", "text": "A counterweight? About a pound? ...The vending machine bags. The Puffy Stars. Trust me, I've bought enough of them to know the heft."},
				{"speaker": "DETECTIVE", "text": "A bag of chips. This case gets more dignified by the minute."},
				{"speaker": "THE ROOKIE", "text": "Machine eats dollars, fair warning. Anything else you need, just ask!"},
			]},
			# --- found the brother file -> point at the OFFICE (the code) ---
			{"flag": "found_murder_weapon", "lines": [
				{"speaker": "THE ROOKIE", "text": "Between us... sometimes I sneak into the captain's office just to look at his medals. Hope I'm that decorated one day."},
				{"speaker": "THE ROOKIE", "text": "It's a whole shrine in there, honestly. The man acts carved out of granite, but... everything he loves is up on that wall."},
				{"speaker": "DETECTIVE", "text": "Everything he loves. ...Hm. Kid - anything you need, it's yours. Later."},
			]},
			# --- knows about the passage -> the end of the loop ---
			{"flag": "captain_is_guilty", "lines": [
				{"speaker": "THE ROOKIE", "text": "You've got a face like a funeral, detective. Whatever you found... be careful when the clock runs out. Midnight's when things go wrong around here."},
				{"speaker": "DETECTIVE", "text": "Yeah. I've noticed."},
				{"speaker": "THE ROOKIE", "text": "I mean it. Anything you need - I'm your guy."},
			]},
			# --- THE PAYOFF: after the taught death, you take him up on it.
			# (Also fires from the auto-intro; this covers walking up to him.) ---
			{"flag": "taught_death_seen", "sets_flag": "have_rookie", "lines": [
				{"speaker": "THE ROOKIE", "text": "Coffee, detective? Two sug-"},
				{"speaker": "DETECTIVE", "text": "You keep asking if I need anything, kid. ...Actually. I do."},
				{"speaker": "THE ROOKIE", "text": "...Wait. Really? What do you need?"},
				{"speaker": "DETECTIVE", "text": "When that clock reads 11:59:45, be in the locker room. Hidden. Not a sound, no matter what you hear - you just remember every word."},
				{"speaker": "DETECTIVE", "text": "And I'll be there holding the PROOF - the package from the evidence room. Your ears, my paper. It takes both, or he buries us both."},
				{"speaker": "THE ROOKIE", "text": "Locker room. 11:59:45. Invisible. You bring the package. ...I won't let you down, detective."},
			]},
			# --- recruited: he makes the meet on his own ---
			{"flag": "have_rookie", "lines": [
				{"speaker": "THE ROOKIE", "text": "0:15. Locker room. I'll be there, detective."},
			]},
		]
	strip_root_motion = true
	super._ready()
	add_to_group("talkable")
	add_to_group("rookie")
	global_position = spawn_pos


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	super._process(delta)
	if get_tree().paused:
		return
	# recruited: he does NOT tail you. He keeps his post, then heads off ON
	# HIS OWN to make the meet - "locker room, 0:15" - leaving early enough
	# to be hidden there when the clock reads 0:15 (t165).
	if Flags.has_flag("have_rookie") and not Flags.has_loop_flag("rookie_staged") \
			and _state in ["posted", "to_post"] \
			and _clock != null and _clock.time >= stage_go_time:
		_state = "staging"
	match _state:
		"approach":
			# the opening monologue owns the screen - don't start the coffee
			# beat (which would open a dialogue and freeze the intro) until the
			# intro has handed over control (bound_promise).
			if not Flags.has_flag("bound_promise"):
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				return
			# delay reads the loop clock, not an own timer - determinism
			if _clock == null:
				_clock = get_tree().get_first_node_in_group("loop_clock")
			if _clock == null or _clock.time < start_delay:
				# waiting for his cue: stand idle at his post, don't drift
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				return
			if not _locked:
				_locked = true
				_set_player_locked(true)
			if _player_body == null:
				_player_body = get_tree().get_first_node_in_group("player")
				if _player_body == null:
					return
			# clamp the chase target INTO the rookie's own room - he walks
			# to the player when they're here, and only to the room's edge
			# when they're not, so he can never straight-line through a wall
			var target := _clamp_to_home(_player_body.global_position)
			if _step_toward(target, approach_distance, delta, _approach_speed_now()):
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				_state = "talk"
			else:
				# SAFETY: if the player is out of the bullpen the clamped
				# target never reaches them - don't hold the player's input
				# hostage. After ~6s of not reaching, unlock and post up.
				_approach_wait += delta
				if _approach_wait > 6.0:
					_set_player_locked(false)
					_state = "to_post"
		"talk":
			# keep easing to face the player while the intro plays out - no
			# hard snap when he arrives
			if _player_body != null:
				_face(_player_body.global_position, delta)
			# the dialogue box may be busy (trinket beat) - retry until
			# free. Safety: if it never frees within ~8s (some other
			# dialogue stuck open), give up and unlock so the player is
			# never permanently frozen.
			if not _intro_opened:
				_talk_wait += delta
				if _talk_wait > 8.0:
					_intro_opened = true
					_finish_intro()
				else:
					_try_open_intro()
		"to_post":
			if _step_toward(post_pos, 0.15, delta, approach_speed):
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				_state = "posted"
		"posted":
			# idle at post; if recruited, the top-of-frame check sends him to
			# the meet when it's time
			play("idle")
			if anim_player != null:
				anim_player.speed_scale = 1.0
			# don't stare at the wall: track the detective when they're
			# around, otherwise stand facing the room like a person would
			if _player_body == null:
				_player_body = get_tree().get_first_node_in_group("player")
			if _player_body != null:
				var flat := _player_body.global_position - global_position
				flat.y = 0.0
				if flat.length() < 6.0:
					_face(_player_body.global_position, delta)
				else:
					_face(Vector3(0.0, 0.0, 0.0), delta)
		"staging":
			# off to the meet: walk to the hiding spot outside the locker room
			var spot := _stage_target()
			if _step_toward(spot, 0.2, delta, approach_speed):
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				# he's hidden and ready - the endgame director reads this.
				# TRULY hidden: the player's own route to the meet passes his
				# spot, so he goes invisible until his entrance - the reveal
				# is "I did, Captain", not passing him in the hallway
				Flags.set_loop_flag("rookie_staged")
				visible = false
				if is_in_group("talkable"):
					remove_from_group("talkable")
				# no invisible wall: his blocking capsule sits right on the
				# player's own path to the meet
				for cs in find_children("*", "CollisionShape3D", true, false):
					cs.disabled = true
				_state = "staged"
		"staged":
			play("idle")
			if anim_player != null:
				anim_player.speed_scale = 1.0
		"step_in":
			# the reveal: through the door, plant himself, face the captain
			var m := _find_spot(step_in_spot)
			var target := m.global_position if m != null else global_position
			if _step_toward(target, 0.2, delta, approach_speed):
				play("idle")
				if anim_player != null:
					anim_player.speed_scale = 1.0
				_state = "staged"


## Called by the endgame director mid-confrontation: the rookie was waiting
## outside the door, unseen - now he appears and walks in for "I did, Captain."
func step_in() -> void:
	if _state == "staged":
		visible = true
		for cs in find_children("*", "CollisionShape3D", true, false):
			cs.disabled = false
		_state = "step_in"


# world position of the hidden marker the rookie tucks into
func _stage_target() -> Vector3:
	var m := _find_spot(stage_spot_name)
	if m != null:
		return m.global_position
	return global_position


func _find_spot(spot: String) -> Node3D:
	var root := get_tree().root
	if "/" in spot:
		var parts := spot.split("/")
		var owner_node := root.find_child(parts[0], true, false)
		if owner_node != null:
			return owner_node.find_child(parts[1], true, false) as Node3D
		return null
	return root.find_child(spot, true, false) as Node3D


# clamp a world point to lie inside the rookie's home room, so his
# approach target can never sit on the far side of a wall
func _clamp_to_home(p: Vector3) -> Vector3:
	if _home_room == null:
		if home_room_path != NodePath():
			_home_room = get_node_or_null(home_room_path)
		if _home_room == null:
			var rooms := get_tree().get_nodes_in_group("room")
			for r in rooms:
				if String(r.name) == "Bullpen":
					_home_room = r
					break
	if _home_room == null or not _home_room.has_method("contains_point"):
		return p
	if _home_room.contains_point(p, 0.0):
		return p
	# player is outside our room: aim for our room's centre instead of
	# chasing them out the door and through walls
	return _home_room.room_center()


func _approach_speed_now() -> float:
	# he learns the routine too: each loop he hustles harder, capped at
	# ~2x by the fourth night
	return approach_speed * minf(1.0 + 0.35 * float(maxi(Flags.loops - 1, 0)), 2.1)


func _step_toward(target: Vector3, stop_at: float, delta: float, speed: float) -> bool:
	var flat := target - global_position
	flat.y = 0.0
	if flat.length() <= stop_at:
		return true
	var dir := flat.normalized()
	global_position += dir * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 8.0)
	var running := speed > Tuning.RUN_PACE
	play("run" if running else "walk")
	if anim_player != null:
		anim_player.speed_scale = clampf(
				speed / (Tuning.RUN_PACE if running else Tuning.WALK_PACE), 0.7, 1.6)
	return false


func _face(target: Vector3, delta: float) -> void:
	var d := target - global_position
	if d.length() > 0.01:
		# ease, don't snap - matches every other heading turn in the game
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), delta * 8.0)


# The auto-played opening beat: a ROTATING pool of short coffee exchanges
# (rotates on the loop count, so coming back keeps it fresh - and the
# detective isn't always gracious about it). Two overrides: the loop after
# the taught death it becomes the recruit payoff, and once recruited it's
# just a nod. The HINTS live in dialogue_variants (walk up and talk to him).
func _pick_intro() -> Dictionary:
	if Flags.has_flag("taught_death_seen") and not Flags.has_flag("have_rookie"):
		return {"sets_flag": "have_rookie", "lines": [
			{"speaker": "THE ROOKIE", "text": "Coffee, detective? Two sug-"},
			{"speaker": "DETECTIVE", "text": "You keep asking if I need anything, kid. ...Actually. I do."},
			{"speaker": "THE ROOKIE", "text": "...Wait. Really? What do you need?"},
			{"speaker": "DETECTIVE", "text": "When that clock reads 0:15, be in the locker room. Hidden. Not a sound, no matter what you hear - you just remember every word."},
			{"speaker": "DETECTIVE", "text": "And I'll be there holding the PROOF - the package from the evidence room. Your ears, my paper. It takes both, or he buries us both."},
			{"speaker": "THE ROOKIE", "text": "Locker room. 0:15. Invisible. You bring the package. ...I won't let you down, detective."},
		]}
	if Flags.has_flag("have_rookie"):
		return {"sets_flag": "", "lines": [
			{"speaker": "THE ROOKIE", "text": "0:15. Locker room. I'll be there, detective."},
		]}
	var pool := [
		[
			{"speaker": "THE ROOKIE", "text": "Coffee, detective! Two sugars, like always. You look like you slept at your desk again."},
			{"speaker": "DETECTIVE", "text": "Kid, my shift ends in three minutes. It always does."},
			{"speaker": "THE ROOKIE", "text": "...It's still warm. Mostly."},
		],
		[
			{"speaker": "THE ROOKIE", "text": "Coffee, detective! Fresh pot, brewed it my-"},
			{"speaker": "DETECTIVE", "text": "Coffee. Yeah, yeah. It's fine. Put it down."},
			{"speaker": "THE ROOKIE", "text": "...Somebody woke up on the wrong side of the precinct."},
		],
		[
			{"speaker": "THE ROOKIE", "text": "Still filing, detective. SO much filing. Shouldn't you be halfway home by now?"},
			{"speaker": "DETECTIVE", "text": "Don't remind me, kid."},
		],
		[
			{"speaker": "THE ROOKIE", "text": "Cells are all prepped - your witness is tucked in safe and sound. We did good tonight, right?"},
			{"speaker": "DETECTIVE", "text": "...Ask me again at midnight."},
		],
	]
	return {"sets_flag": "", "lines": pool[Flags.loops % pool.size()]}


func _try_open_intro() -> void:
	_dialogue_ui = get_tree().get_first_node_in_group("dialogue")
	if _dialogue_ui == null:
		_intro_opened = true
		_finish_intro()
		return
	if _dialogue_ui.visible:
		return
	_intro_opened = true
	_dialogue_ui.closed.connect(_finish_intro, CONNECT_ONE_SHOT)
	_play_voice()
	var convo := _pick_intro()
	_dialogue_ui.show_dialogue(convo.get("lines", []), convo.get("sets_flag", ""))


func _finish_intro() -> void:
	# the punchline to every coffee exchange: the detective actually takes
	# the sip, every single loop
	CoffeeSfx.play_at(self, "res://audio/sfx/coffee.mp3", -8.0, 3.0)
	_set_player_locked(false)
	_state = "to_post"


func _set_player_locked(locked: bool) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.input_locked = locked
