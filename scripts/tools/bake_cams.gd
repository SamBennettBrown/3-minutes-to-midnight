extends Node

# Prints every room/zone camera's LOCAL transform after auto-aim ran,
# in .tscn Transform3D form - used once to bake aims into the scenes.

const Flags := preload("res://scripts/game/flags.gd")


func _ready() -> void:
	Flags.set_flag("intro_done")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	for room in get_tree().get_nodes_in_group("room"):
		for c in room.get_children():
			if c is Camera3D:
				_dump(room.name, "room", c, room)
			elif c is Area3D and c.has_method("zone_camera") and c.zone_camera() != null:
				_dump(room.name, c.name, c.zone_camera(), c)
	get_tree().quit()


func _dump(room: String, tag: String, cam: Camera3D, parent: Node3D) -> void:
	var t: Transform3D = parent.global_transform.affine_inverse() * cam.global_transform
	var b := t.basis
	var o := t.origin
	print("BAKE %s|%s|Transform3D(%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f)" % [
		room, tag,
		b.x.x, b.y.x, b.z.x, b.x.y, b.y.y, b.z.y, b.x.z, b.y.z, b.z.z,
		o.x, o.y, o.z])
