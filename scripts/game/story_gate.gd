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
var _cells_open := false


func _enter_tree() -> void:
	add_to_group("story_gate")


func _ready() -> void:
	# rooms need to be in the tree with their markers resolved
	_refresh.call_deferred()


func _process(_delta: float) -> void:
	# the allow-set can change WITHIN a phase (loop 0 opens the cells + hall 2
	# at the gunshot, without the phase string changing), so track both the
	# phase and the cells-unlocked flag and refresh when either flips
	var want := _phase_for_now()
	var cells_open: bool = Flags.has_loop_flag("cells_unlocked")
	if want != _phase or cells_open != _cells_open:
		_refresh()


func _phase_for_now() -> String:
	if not Flags.has_flag("intro_done"):
		# loop 0: the cells open only once the gunshot has sounded
		return "loop0"
	match Flags.loops:
		1: return "loop1"
		# loop 2 onward: the corridors are all open. The rooms that should
		# stay shut (evidence, interrogation) are held by their OWN gates -
		# a keycard reader and the interrogation door - so approaching them
		# gives the right in-fiction "locked" line instead of a blank wall.
		_: return "open"


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
	_cells_open = Flags.has_loop_flag("cells_unlocked")
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
				# face the thin blocker across the doorway: the door faces
				# away from the room centre, so the wall runs perpendicular to
				# the centre->door direction
				var face: Vector3 = m.global_position - room.room_center()
				_block_at(m.global_position, face)


func _block_at(pos: Vector3, face: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# a slim slab that just plugs the door gap - wide enough to span the
	# opening, thin enough not to jut into the room/hall
	box.size = Vector3(2.2, 3.0, 0.4)
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, 1.5, 0)
	# rotate so the slab's thin axis (local Z) points along the doorway's
	# through-direction (centre -> door), i.e. the slab spans the opening
	face.y = 0.0
	if face.length() > 0.05:
		body.rotation.y = atan2(face.x, face.z)
	_blocks.append(body)


func _clear() -> void:
	for b in _blocks:
		if is_instance_valid(b):
			b.queue_free()
	_blocks.clear()
