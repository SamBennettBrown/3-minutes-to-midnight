# Shared "who can I interact with" lookup. Both the E-prompt
# (interact_prompt.gd) and the actual interact (player_controller.gd)
# call this so the prompt always appears over the exact node the E key
# will act on - they can never disagree.
#
#   const Interact := preload("res://scripts/game/interact.gd")
#   var target := Interact.nearest(tree, from_pos, Tuning.INTERACT_RANGE)

const Tuning := preload("res://scripts/game/tuning.gd")
const RoomState := preload("res://scripts/game/room.gd")


static func nearest(tree: SceneTree, from: Vector3, reach := Tuning.INTERACT_RANGE) -> Node3D:
	var best := reach
	var found: Node3D = null
	# only things in the ACTIVE room count - rooms share walls, and a pure
	# distance check would let you interact with a prop on the far side of a
	# shared wall (e.g. the evidence package from the captain's office next
	# door). Anything outside the current room's floor footprint is unreachable.
	var room = RoomState.current
	for n in tree.get_nodes_in_group("talkable"):
		var d: float = from.distance_to(n.global_position)
		if d >= best:
			continue
		if room != null and room.has_method("contains_floor_point") \
				and not room.contains_floor_point(n.global_position, 0.5):
			continue
		best = d
		found = n
	return found
