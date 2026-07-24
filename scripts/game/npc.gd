@tool
extends "res://scripts/player/player.gd"

const Tuning := preload("res://scripts/game/tuning.gd")

# An NPC on rails: every loop it does exactly the same thing at exactly
# the same moment, driven by the loop clock - never by physics, timers,
# or RNG, so the timeline is perfectly reproducible.
#
# schedule: ordered entries {t, pos|spot, clip} - at time t the NPC is
# AT that place; until the next entry it lerps toward the next place
# while playing THIS entry's clip. Wraps at the last entry's t.
#
# Prefer "spot" (a Marker3D named "Bullpen/DoorEast") over raw "pos":
# move or resize the room and every path through its spots stays correct.

const Sfx := preload("res://scripts/game/sfx.gd")

## the walk clip's natural pace (m/s) - actual speed scales the
## animation so feet don't slide
@export var walk_pace := Tuning.WALK_PACE

## empty = stand wherever the scene placed you; entries take over from
## there. NOTE: schedules must be CLOSED LOOPS - the last entry's pos
## should equal the first's, because time wraps (fmod) with no walk
## segment from last back to first. If they differ, the NPC teleports
## at each loop wrap.
@export var schedule: Array = []

## pace the walk by DISTANCE, not by the authored `t` gaps. When on, a
## "walk" segment takes exactly (distance / walk_pace) seconds and an
## "idle"/"foottap" segment holds for its authored (t_next - t) gap, so
## the NPC always moves at a believable speed no matter how the times
## were entered. The authored `t` on the FIRST entry is the start delay;
## barks still fire on their own absolute `t`. Leave off for schedules
## that must hit exact clock beats.
@export var paced := false

# scheduled overheard lines / sounds, on absolute loop time:
# [{t, text, dur, sound, flag, hear_range}] - text shows as a bark
# above the head; flag only sets if the player is within hear_range
@export var barks: Array = []

## timed glances: [{t, dur, yaw}] - at loop time t the NPC swings its
## heading by `yaw` DEGREES (right = positive) for `dur` seconds, then
## turns back. Used for the receptionist turning to the phone so the card
## on the desk becomes reachable during the call. Only meaningful for a
## standing NPC (empty schedule / idle).
@export var turn_windows: Array = []
## how fast the timed turn eases (higher = snappier)
@export var turn_speed := 4.0

var _clock: Node
var _bark_i := 0
var _last_pos := Vector3.INF
var _spots_resolved := false
var _base_yaw := 0.0
var _base_yaw_set := false


func _ready() -> void:
	strip_root_motion = true
	super._ready()
	add_to_group("talkable")
	_clock = get_tree().get_first_node_in_group("loop_clock")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	super._process(_delta)
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
	if _clock == null or get_tree().paused:
		return
	if not _spots_resolved:
		_resolve_spots()
	while _bark_i < barks.size() and _clock.time >= float(barks[_bark_i].get("t", 1e9)):
		_do_bark(barks[_bark_i])
		_bark_i += 1
	_apply_turn_windows(_delta)
	if schedule.size() < 2:
		return
	var total := float(schedule[-1]["t"])
	# closed loop (ends where it began) = a repeating patrol, so wrap with
	# fmod. Open schedule (ends elsewhere) = a one-time journey, e.g. the
	# escorts walking out for good - CLAMP so they hold the final spot
	# instead of teleporting back to the start when time > total.
	var first_pos: Vector3 = schedule[0]["pos"]
	var last_pos: Vector3 = schedule[-1]["pos"]
	var closed := first_pos.distance_to(last_pos) < 0.5
	var t := fmod(float(_clock.time), total) if closed \
			else minf(float(_clock.time), total)
	var i := 0
	while i < schedule.size() - 2 and t >= float(schedule[i + 1]["t"]):
		i += 1
	var a: Dictionary = schedule[i]
	var b: Dictionary = schedule[i + 1]
	var clip := String(a["clip"])
	var from: Vector3 = a["pos"]
	var to: Vector3 = b["pos"]
	# only a WALK segment travels; idle/foottap/etc. HOLD at `from` so the
	# character doesn't slide across the floor while standing still
	if clip == "walk" or clip == "run":
		var span := float(b["t"]) - float(a["t"])
		var f := 0.0 if span <= 0.0 else clampf((t - float(a["t"])) / span, 0.0, 1.0)
		position = from.lerp(to, f)
		var dir := to - from
		if dir.length() > 0.01:
			# smooth turn - snapping at waypoints reads as a side-step
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), _delta * 8.0)
	else:
		position = from
	play(clip)
	_sync_walk_speed(_delta)


func _sync_walk_speed(delta: float) -> void:
	# feet grip the floor: scale the walk animation to actual velocity
	if _last_pos == Vector3.INF:
		_last_pos = global_position
		return
	var v := (global_position - _last_pos).length() / maxf(delta, 0.0001)
	_last_pos = global_position
	if anim_player == null:
		return
	anim_player.speed_scale = clampf(v / walk_pace, 0.7, 1.5) if current_clip == "walk" else 1.0


# swing the heading during timed glance windows (receptionist -> phone),
# then ease back. Captures the resting heading once so it always returns
# to whatever the scene placed the NPC facing.
func _apply_turn_windows(delta: float) -> void:
	if turn_windows.is_empty():
		return
	if not _base_yaw_set:
		_base_yaw = rotation.y
		_base_yaw_set = true
	var target := _base_yaw
	var now := float(_clock.time)
	var active_flag := ""
	var any_active := false
	for w in turn_windows:
		var t0 := float(w.get("t", 0.0))
		var dur := float(w.get("dur", 0.0))
		if now >= t0 and now < t0 + dur:
			# "right" is a NEGATIVE yaw about +Y (clockwise from above)
			target = _base_yaw - deg_to_rad(float(w.get("yaw", 0.0)))
			active_flag = String(w.get("flag", ""))
			any_active = true
			break
	# expose "is turned away right now" as a loop flag so other things (the
	# desk keycard) can gate on it - single source of truth for the window
	for w in turn_windows:
		var f := String(w.get("flag", ""))
		if f != "" and (not any_active or f != active_flag):
			Flags.clear_loop_flag(f)
	if active_flag != "":
		Flags.set_loop_flag(active_flag)
	rotation.y = lerp_angle(rotation.y, target, delta * turn_speed)


func _resolve_spots() -> void:
	_spots_resolved = true
	for e in schedule:
		if not e.has("pos") and e.has("spot"):
			var m := _find_spot(String(e["spot"]))
			if m != null:
				e["pos"] = m.global_position
			else:
				push_warning("[npc] unknown spot: " + String(e["spot"]))
				e["pos"] = global_position
		# markers can sit slightly off the floor; walking characters must
		# stay planted, so pin every waypoint to floor level
		if e.has("pos"):
			var p: Vector3 = e["pos"]
			e["pos"] = Vector3(p.x, 0.0, p.z)
	if paced:
		_repace_schedule()


# Rewrite each entry's `t` so walk segments run at walk_pace and non-walk
# segments hold for their originally-authored duration. Motion becomes
# speed-correct no matter how the times were hand-entered.
func _repace_schedule() -> void:
	if schedule.size() < 2:
		return
	var pace := maxf(walk_pace, 0.1)
	var t := float(schedule[0].get("t", 0.0))  # start delay preserved
	schedule[0]["t"] = t
	for i in range(1, schedule.size()):
		var prev: Dictionary = schedule[i - 1]
		var cur: Dictionary = schedule[i]
		var dur: float
		if String(prev.get("clip", "")) == "walk":
			var d: float = (Vector3(cur["pos"]) - Vector3(prev["pos"])).length()
			dur = d / pace
		else:
			# hold for the authored gap (a deliberate pause/idle beat)
			dur = maxf(float(cur.get("t", 0.0)) - float(prev.get("t", 0.0)), 0.0)
		t += maxf(dur, 0.05)
		cur["t"] = t


func _find_spot(spot: String) -> Node3D:
	var root := get_tree().root
	if "/" in spot:
		var parts := spot.split("/")
		var owner_node := root.find_child(parts[0], true, false)
		if owner_node != null:
			return owner_node.find_child(parts[1], true, false) as Node3D
		return null
	return root.find_child(spot, true, false) as Node3D


func _do_bark(b: Dictionary) -> void:
	var txt := String(b.get("text", ""))
	if txt != "":
		bark(txt, float(b.get("dur", 3.0)))
	var snd := String(b.get("sound", ""))
	if snd != "" and ResourceLoader.exists(snd):
		# own one-shot player - the footstep player would cut this off;
		# capped so a long recording can't ring the whole loop
		Sfx.play_at(self, snd, -6.0, float(b.get("sound_len", 7.0)))
	var flag := String(b.get("flag", ""))
	if flag != "":
		var p := get_tree().get_first_node_in_group("player")
		if p != null and global_position.distance_to(p.global_position) <= float(b.get("hear_range", 6.0)):
			Flags.set_flag(flag)
