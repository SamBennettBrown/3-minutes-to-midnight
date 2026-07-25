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

## loop time at which this NPC leaves for good and disappears (they've
## walked out of the building - the clerk exiting past the lobby door).
## 0 = never. Reappears on loop restart.
@export var vanish_at := 0.0
## OR: vanish the moment they physically REACH this spot (e.g. "Lobby/Exit")
## - no clock guessing, they disappear right as they hit the door. Empty =
## unused. Reappears on loop restart.
@export var vanish_at_spot := ""

var _clock: Node
var _bark_i := 0
var _last_pos := Vector3.INF
var _spots_resolved := false
var _base_yaw := 0.0
var _base_yaw_set := false
var _gone := false


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
	# the opening monologue owns the screen - nobody moves or barks until the
	# intro hands over control (bound_promise). Otherwise a bark could open a
	# line and pause the tree, freezing the intro.
	if not Flags.has_flag("bound_promise"):
		return
	# left the building for good: hide and stop doing anything until the
	# loop restarts (the clerk exiting past the front door)
	if _gone or (vanish_at > 0.0 and _clock.time >= vanish_at):
		if visible:
			visible = false
			remove_from_group("talkable")
		return
	if not _spots_resolved:
		_resolve_spots()
	# spot-based exit: gone the moment they physically reach the marker
	if vanish_at_spot != "":
		var exit_m := _find_spot(vanish_at_spot)
		if exit_m != null:
			var flat := global_position - exit_m.global_position
			flat.y = 0.0
			if flat.length() < 0.45:
				_gone = true
				visible = false
				remove_from_group("talkable")
				return
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
	# ONE model, shared with _repace_schedule: each entry is a waypoint the
	# character is AT by its `t`. The segment we're on now runs from the
	# PREVIOUS waypoint's pos to the CURRENT target's pos over [prev.t,
	# cur.t], and the CURRENT entry's clip says how we cross it. So `dest` is
	# the first entry whose t is still ahead (or the last one).
	var dest := 1
	while dest < schedule.size() - 1 and t >= float(schedule[dest]["t"]):
		dest += 1
	var cur: Dictionary = schedule[dest]
	var prev: Dictionary = schedule[dest - 1]
	var clip := String(cur["clip"])
	var from: Vector3 = prev["pos"]
	var to: Vector3 = cur["pos"]
	# a "walk"/"run" segment that covers no ground (both waypoints the same
	# spot, e.g. a hold authored as a walk) must NOT play the walk cycle in
	# place - fall back to idle so the character stands still convincingly.
	var moving := (clip == "walk" or clip == "run") and from.distance_to(to) > 0.05
	if moving:
		# travel prev -> cur across the segment's own time window
		var span := float(cur["t"]) - float(prev["t"])
		var f := 0.0 if span <= 0.0 else clampf((t - float(prev["t"])) / span, 0.0, 1.0)
		position = from.lerp(to, f)
		var dir := to - from
		if dir.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), _delta * 8.0)
		play(clip)
	else:
		# a hold: stay put at the destination's own spot
		position = to
		play("idle")
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
	# seed the NPC at its first waypoint so it never TELEPORTS from its
	# authored transform to schedule[0] the moment the schedule engages
	# (the authored transform and schedule[0] are two sources of truth).
	if schedule.size() > 0 and schedule[0].has("pos"):
		position = schedule[0]["pos"]


# Rewrite each entry's `t` so a TRAVELING segment runs at walk_pace and a
# HOLD keeps its authored duration. Uses the SAME model as the _process
# lerp: the segment from entry i-1 to entry i is described by entry i's
# clip - a "walk"/"run" there means you cross that distance at pace;
# anything else (idle) is a hold for the authored gap.
func _repace_schedule() -> void:
	if schedule.size() < 2:
		return
	var pace := maxf(walk_pace, 0.1)
	var t := float(schedule[0].get("t", 0.0))  # start delay preserved
	schedule[0]["t"] = t
	for i in range(1, schedule.size()):
		var prev: Dictionary = schedule[i - 1]
		var cur: Dictionary = schedule[i]
		# "until" pins this entry to an ABSOLUTE clock beat - pacing turns
		# authored times into relative gaps, which makes exact departures
		# ("the investigator leaves the cells at 1:00 on the dot") drift.
		# A pinned hold ends at its authored moment no matter how long the
		# paced walk took to get there.
		if cur.has("until"):
			t = maxf(float(cur["until"]), t + 0.05)
			cur["t"] = t
			continue
		var moves: bool = String(cur.get("clip", "")) == "walk" \
				or String(cur.get("clip", "")) == "run"
		var d: float = (Vector3(cur["pos"]) - Vector3(prev["pos"])).length()
		var dur: float
		# a traveling segment is paced by distance when it covers ground;
		# a hold (or a zero-distance walk-in-place) keeps its authored gap.
		if moves and d > 0.05:
			dur = d / pace
		else:
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
