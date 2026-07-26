extends Light3D

# A light tied to the loop clock: ON until `off_at`, dark after. Used for
# diegetic signposting - the warm leak around the observation window dies
# the moment the interrogation empties out.

@export var off_at := 64.0

var _clock: Node


func _process(_delta: float) -> void:
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	visible = float(_clock.time) < off_at
