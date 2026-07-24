extends Node

# One place that decides which rooms the player may enter during the
# scripted opening. Loops 0 and 1 are on rails - you can't wander off,
# grab the keycard early, or explore. Instead of a flag_gate on every
# doorway, this reads each room's Door* markers and drops an invisible
# wall across any doorway that leads into a room the current phase does
# NOT allow. When the phase opens up (loop 3+), the walls come down.
#
# Phases are driven by the loop count + intro_done, so this re-evaluates
# every loop with no per-scene wiring.

const Flags := preload("res://scripts/game/flags.gd")

# room name -> the set of rooms reachable/allowed in that phase. A door
# is blocked when EITHER side is a room not in the allowed set.
const PHASES := {
	# loop 0: desk errand then the cells after the gunshot
	"loop0": ["Bullpen", "Lobby", "Cells", "Hall2"],
	# loop 1: you just want to go home - bullpen and the lobby only
	"loop1": ["Bullpen", "Lobby"],
	# loop 2: learn the murder - bullpen, hall 1, observation (interro is
	# locked by its own DoorGate, funnelling you to the glass)
	"loop2": ["Bullpen", "Hall1", "Observation", "Lobby"],
}

# marker name -> the room it leads INTO (so we know what a doorway gates)
const LEADS_TO := {
	"DoorLobby": "Lobby", "DoorBullpen": "Bullpen", "DoorCaptain": "CaptainsOffice",
	"DoorEvidence": "Evidence", "DoorHall1": "Hall1", "DoorHall2": "Hall2",
	"MouthBullpen": "Bullpen", "DoorInterrogation": "Interrogation",
	"DoorObservation": "Observation", "DoorLocker": "LockerRoom",
	"DoorCells": "Cells",
}

var _blocks: Array = []
var _phase := ""


func _enter_tree() -> void:
	add_to_group("story_gate")


func _ready() -> void:
	# rooms need to be in the tree with their markers resolved
	_refresh.call_deferred()


func _process(_delta: float) -> void:
	# the phase can change mid-loop (loop 0 opens the cells at the gunshot),
	# so re-check when the allow-set would differ
	var want := _phase_for_now()
	if want != _phase:
		_refresh()


func _phase_for_now() -> String:
	if not Flags.has_flag("intro_done"):
		# loop 0: the cells open only once the gunshot has sounded
		return "loop0"
	match Flags.loops:
		1: return "loop1"
		2: return "loop2"
		_: return "open"  # loop 3+: explore freely


func _allowed_set() -> Dictionary:
	var out := {}
	var phase := _phase_for_now()
	if not PHASES.has(phase):
		return out  # "open" -> empty means nothing blocked
	for r in PHASES[phase]:
		out[r] = true
	# loop 0's cells stay sealed until the gunshot frees them
	if phase == "loop0" and not Flags.has_loop_flag("cells_unlocked"):
		out.erase("Cells")
		out.erase("Hall2")
	return out


func _refresh() -> void:
	_phase = _phase_for_now()
	_clear()
	if _phase == "open":
		return
	var allowed := _allowed_set()
	for room in get_tree().get_nodes_in_group("room"):
		var here_ok: bool = allowed.has(String(room.name))
		var spots := room.get_node_or_null("Spots")
		if spots == null:
			continue
		for m in spots.get_children():
			var dest: String = LEADS_TO.get(String(m.name), "")
			if dest == "":
				continue
			var dest_ok: bool = allowed.has(dest)
			# block the doorway when it bridges allowed <-> not-allowed
			if here_ok != dest_ok:
				_block_at(m.global_position)


func _block_at(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 3.0, 3.2)
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, 1.5, 0)
	_blocks.append(body)


func _clear() -> void:
	for b in _blocks:
		if is_instance_valid(b):
			b.queue_free()
	_blocks.clear()
