extends SceneTree

# Prints the AABB of key Synty building modules so rooms can be built
# to the pack's real grid. Run:
#   godot --headless --path . -s res://scripts/tools/measure_probe.gd

const PIECES := [
	"SM_Bld_Wall_Cell_01", "SM_Bld_Wall_Door_01", "SM_Bld_Wall_Reception_01",
	"SM_Bld_Wall_Window_Large_01", "SM_Bld_Door_01", "SM_Bld_Wall_Block_01",
	"SM_Bld_Wall_Trim_01",
]
const DIR := "res://POLYGON_Police_Station_SourceFiles_v3/SourceFiles/FBX/"


func _initialize() -> void:
	for n in PIECES:
		var path: String = DIR + String(n) + ".fbx"
		if not ResourceLoader.exists(path):
			print("MEASURE %s: not found/imported" % n)
			continue
		var scene: Node = (load(path) as PackedScene).instantiate()
		var aabb := _merged_aabb(scene)
		print("MEASURE %s: size %.2f x %.2f x %.2f (w/h/d)" % [n, aabb.size.x, aabb.size.y, aabb.size.z])
		scene.free()
	quit()


func _merged_aabb(node: Node) -> AABB:
	var total := AABB()
	var first := true
	var stack := [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var a: AABB = n.global_transform * n.get_aabb() if n.is_inside_tree() else n.transform * n.get_aabb()
			if first:
				total = a
				first = false
			else:
				total = total.merge(a)
		for c in n.get_children():
			stack.append(c)
	return total
