extends Node

# LEGACY - the scripted opening (loops 0/1/2) is gone. Rooms are no longer
# sealed by phase; the whole station is open from the first loop. What the
# player can DO is gated by knowledge (the journal breadcrumb) and by each
# room's own in-fiction locks (the interrogation DoorGate, the evidence
# keycard reader, the tunnel's LockerGate) - never by an invisible wall.
#
# This node is kept as an inert stub so the world scene's reference stays
# valid; it blocks nothing. Safe to delete the node entirely later.


func _enter_tree() -> void:
	add_to_group("story_gate")
