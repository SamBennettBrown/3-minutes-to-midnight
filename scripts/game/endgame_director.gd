extends Node

# The endgame. Everything up to here is investigation; this node owns the
# final confrontation and nothing else does. It watches for ONE condition:
#
#   * you have PROVEN the captain guilty  (flag `captain_is_guilty`), AND
#   * the clock is in the intercept window (2:45-3:00, t165-180), AND
#   * you are standing in the LOCKER ROOM, where the captain is about to slip
#     into the passage.
#
# When all three are true it FREEZES the loop clock (the night never reaches
# 0:00, so the witness is never shot) and runs the confrontation:
#
#   - ROOKIE NOT STAGED -> a TAUGHT death. The captain kills you; the lose
#     screen holds a lesson: you can't take him alone, you need a living
#     witness. Sets `taught_death_seen`, then the loop resets.
#   - ROOKIE STAGED (hidden in the locker room, `rookie_staged`) -> the WIN.
#     The captain confesses to you, the rookie steps out as the witness who
#     lives, the loop BREAKS (`loop_broken`), and the credits roll.
#
# Design record: docs/DESIGN.md "The solve (endgame)".

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

## the intercept window, in loop seconds (2:45 -> 3:00 on a 180s loop)
@export var window_start := 165.0
@export var window_end := 180.0
## the captain must actually BE in the locker room to intercept (he vanishes
## into the passage a little after the window). Matched by node name.
@export var captain_name := "Captain"
@export var locker_room_name := "LockerRoom"

## the lesson shown on the taught death
@export var taught_line := "He'd shoot me and call it self-defence - my word against a captain's, and I'm the one who ends up in a cell. I can't take him alone. I need someone who lives to see this."
## the lesson when the rookie was hidden but your hands were empty
@export var no_evidence_line := "Words are wind. I need the PROOF in my hand - the package from the evidence room, the photo of him and his brother. Grab it first, THEN corner him."

var _clock: Node
var _fired := false
var _pulse := false


func _enter_tree() -> void:
	add_to_group("endgame_director")


func _process(_delta: float) -> void:
	if _fired:
		return
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		if _clock == null:
			return
	# gate 1: you must have proven his guilt. No stumbling into the ending.
	if not Flags.has_flag("captain_is_guilty"):
		return
	# gate 2: the intercept window (2:45-3:00)
	var t: float = _clock.time
	if t < window_start or t > window_end:
		return
	# gate 3: you're in the locker room, and the captain is here too (he
	# hasn't slipped into the passage yet)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# the locker room counts - and so does the NOOK behind the locker.
	# But they end DIFFERENTLY: the locker room is the intercept; the nook
	# is HIS pocket, and standing in it at his hour gets you shot from
	# behind - a taught death, not a silent nothing.
	var locker := _find_room(locker_room_name)
	var in_locker: bool = locker != null \
			and locker.contains_point(player.global_position, 0.0)
	var in_nook := false
	if not in_locker:
		var nook := _find_room("Tunnel")
		in_nook = nook != null and nook.contains_point(player.global_position, 0.0)
	if not in_locker and not in_nook:
		return
	var captain := _find_captain()
	if captain == null or not captain.visible:
		return
	_fired = true
	if in_nook:
		_nook_death()
	else:
		_intercept(captain)


func _intercept(captain: Node3D) -> void:
	# hold the night open - the murder never lands
	_clock.frozen = true
	# the world holds its breath: every room hum sinks away, and only a
	# slow heartbeat stays under the voices
	for amb in get_tree().get_nodes_in_group("room_ambient"):
		if amb.has_method("hush"):
			amb.hush()
	_start_heartbeat()
	# The WIN needs BOTH per-loop holdings, re-done this very run:
	#  - rookie_staged: the living witness, hidden in the locker room
	#  - have_evidence_package: the brother-proof photo, physically in hand
	# Missing either = the confrontation fails and teaches what was missing.
	if Flags.has_loop_flag("rookie_staged") and Flags.has_loop_flag("have_evidence_package"):
		_win(captain)
	elif Flags.has_loop_flag("rookie_staged"):
		_no_evidence_death()
	else:
		_taught_death()


# the slow pulse under the confrontation. Pauses with the tree (dialogue
# up = silence between lines), dies with the scene when the loop ends.
func _start_heartbeat() -> void:
	var t := Timer.new()
	t.wait_time = 1.2
	t.autostart = true
	t.timeout.connect(func() -> void:
		_pulse = not _pulse
		Sfx.play(self, "res://audio/sfx/heartbeat1.mp3" if _pulse \
				else "res://audio/sfx/heartbeat2.mp3", -16.0))
	add_child(t)


# --- caught inside HIS nook: shot from behind, a positioning lesson ---
func _nook_death() -> void:
	_clock.frozen = true
	Flags.set_flag("taught_death_seen")
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and not dlg.visible:
		dlg.show_dialogue([
			{"speaker": "THE CAPTAIN", "text": "...My locker, standing open. And a detective in my favourite little room."},
			{"speaker": "DETECTIVE", "text": "The floor creaked behind me. I never even got to turn around."},
		])
		await dlg.closed
		if not is_inside_tree():
			return
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		lose.play_lose("His nook. His hour. He walked in BEHIND me and that was that. If I want to catch him, I wait OUTSIDE the locker - in the locker room - not inside his own pocket.")


# --- alone: the lesson ---
func _taught_death() -> void:
	Flags.set_flag("taught_death_seen")
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and not dlg.visible:
		dlg.show_dialogue([
			{"speaker": "THE CAPTAIN", "text": "You. In MY locker room, at MY hour. You really don't stop."},
			{"speaker": "DETECTIVE", "text": "I know what's behind that wall, Captain. I know what you do down there."},
			{"speaker": "THE CAPTAIN", "text": "Then you know how this ends. No witness, no case. Just a detective who wouldn't go home."},
		])
		await dlg.closed
		if not is_inside_tree():
			return
	_die_with_lesson()


func _die_with_lesson() -> void:
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		# the frozen clock is about to be wiped by the reload anyway
		lose.play_lose(taught_line)


# --- rookie hidden but EMPTY-HANDED: an accusation with no proof ---
func _no_evidence_death() -> void:
	Flags.set_flag("taught_death_seen")
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and not dlg.visible:
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "It's over, Captain. I know what's behind your locker. I know about your brother."},
			{"speaker": "THE CAPTAIN", "text": "My brother? Show me. Show me one shred of paper that says any of that out loud."},
			{"speaker": "DETECTIVE", "text": "..."},
			{"speaker": "THE CAPTAIN", "text": "That's what I thought. ...And whoever's breathing back there - you can come out too, son."},
			{"speaker": "THE ROOKIE", "text": "...Sir, I-"},
		])
		await dlg.closed
		if not is_inside_tree():
			return
	var lose := get_tree().get_first_node_in_group("lose_screen")
	if lose != null:
		lose.play_lose(no_evidence_line)


# --- with the rookie: the win ---
func _win(captain: Node3D) -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null:
		_roll_credits()
		return
	if dlg.visible:
		# something else is mid-line; wait a beat and re-drive
		await dlg.closed
	dlg.show_dialogue([
		{"speaker": "THE CAPTAIN", "text": "Out of my way, detective. I have a loose end to take care of"},
		{"speaker": "DETECTIVE", "text": "Recognize this? Two brothers at a lake. The other one is sitting in a jail cell because of MY witness."},
		{"speaker": "THE CAPTAIN", "text": "...Where did you get that?"},
		{"speaker": "DETECTIVE", "text": "Where you left it. You hid it in away in the evidence room behind the shelf. Using the hidden passage behind that locker, you're about to put him down for good."},
		{"speaker": "THE CAPTAIN", "text": "So what, gumshoe? It's your word against mine, and mine wears more brass. Nobody will know a thing."},
	])
	await dlg.closed
	if not is_inside_tree():
		return
	# THE reveal: the rookie was outside the door the whole time - he steps
	# in through the doorway before delivering the line
	var rookie := get_tree().get_first_node_in_group("rookie")
	if rookie != null and rookie.has_method("step_in"):
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			p.input_locked = true
		rookie.step_in()
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree():
			return
	dlg.show_dialogue([
		{"speaker": "THE ROOKIE", "text": "I did, Captain. I heard every word of it."},
		{"speaker": "THE CAPTAIN", "text": "...You. How long have you-"},
		{"speaker": "DETECTIVE", "text": "Long enough. The photo, and a witness who lives. The two things you could never plan around. It's over."},
		{"speaker": "DETECTIVE", "text": "I think it's about time you... *takes off glasses*"},
		{"speaker": "DETECTIVE", "text": "Clocked out, Captain "},
		{"speaker": "CSI MIAMI", "text": "YEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAH!!"},
		{"speaker": "THE ROOKIE", "text": "Sir... it's three minutes past midnight. Does this count as overtime?"},
		{"speaker": "DETECTIVE", "text": "Kid, I've worked this same three minutes more times than I can count. The department owes me a YEAR."},
	])
	await dlg.closed
	if not is_inside_tree():
		return
	_roll_credits()


func _roll_credits() -> void:
	Flags.set_flag("loop_broken")
	var credits := get_tree().get_first_node_in_group("credits")
	if credits != null:
		# win mode: closing the credits resets the run and returns to the
		# title, so the next START replays the intro - the loop is broken
		credits.open(true)


# --- lookups ---
func _find_room(room_name: String) -> Node3D:
	for r in get_tree().get_nodes_in_group("room"):
		if String(r.name) == room_name:
			return r
	return null


func _find_captain() -> Node3D:
	var n := get_tree().get_root().find_child(captain_name, true, false)
	return n as Node3D
