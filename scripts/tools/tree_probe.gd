extends SceneTree


func _init() -> void:
	for path in ["res://scripts/tools/retarget/idle_rt.glb", "res://scripts/tools/retarget/ork_rt.glb"]:
		var inst: Node = (load(path) as PackedScene).instantiate()
		print("PROBE ", path)
		_dump(inst, inst, 0)
		inst.free()
	quit()


func _dump(node: Node, root: Node, depth: int) -> void:
	print("PROBE   %s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()])
	if depth < 3:
		for child in node.get_children():
			_dump(child, root, depth + 1)
