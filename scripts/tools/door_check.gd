extends Node

# Door-coverage audit: for every room, checks that each door/mouth spot
# is inside that room's camera frustum (with a margin). Prints a PASS/
# MISS line per door. Run:
#   godot --headless --path . res://scripts/tools/door_check.tscn

const Flags := preload("res://scripts/game/flags.gd")


func _ready() -> void:
	Flags.set_flag("intro_done")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	for room in get_tree().get_nodes_in_group("room"):
		var cams: Array = []
		for c in room.get_children():
			if c is Camera3D:
				cams.append(c)
			elif c is Area3D and c.has_method("zone_camera") and c.zone_camera() != null:
				cams.append(c.zone_camera())
		var spots := room.get_node_or_null("Spots")
		if spots == null or cams.is_empty():
			continue
		for m in spots.get_children():
			var n := String(m.name)
			if not (n.begins_with("Door") or n.begins_with("Mouth") or n == "Exit"):
				continue
			var p: Vector3 = m.global_position + Vector3(0, 1.0, 0)
			var seen_by := []
			for cam in cams:
				if cam.is_position_in_frustum(p):
					seen_by.append(String(cam.get_parent().name) if cam.get_parent() != room else "room")
			if seen_by.is_empty():
				print("MISS  %s / %s" % [room.name, n])
			else:
				print("pass  %s / %s  (%s)" % [room.name, n, ", ".join(seen_by)])
	get_tree().quit()
