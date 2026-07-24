# Shared "who can I interact with" lookup. Both the E-prompt
# (interact_prompt.gd) and the actual interact (player_controller.gd)
# call this so the prompt always appears over the exact node the E key
# will act on - they can never disagree.
#
#   const Interact := preload("res://scripts/game/interact.gd")
#   var target := Interact.nearest(tree, from_pos, Tuning.INTERACT_RANGE)

const Tuning := preload("res://scripts/game/tuning.gd")


static func nearest(tree: SceneTree, from: Vector3, reach := Tuning.INTERACT_RANGE) -> Node3D:
	var best := reach
	var found: Node3D = null
	for n in tree.get_nodes_in_group("talkable"):
		var d: float = from.distance_to(n.global_position)
		if d < best:
			best = d
			found = n
	return found
