extends SceneTree

const FILES := [
	"res://POLYGON_Police_Station_SourceFiles_v3/SourceFiles/FBX/SM_Prop_Weapon_Locker_01.fbx",
	"res://POLYGON_Office_SourceFiles_v4/SourceFiles/FBX/SM_Prop_Computer_Monitor_01.fbx",
	"res://POLYGON_Office_SourceFiles_v4/SourceFiles/FBX/SM_Prop_Computer_Monitor_Double_01.fbx",
]

func _initialize() -> void:
	for f in FILES:
		var fp: String = f
		if not ResourceLoader.exists(fp):
			print("PROBE %s: NOT IMPORTED" % fp.get_file())
			continue
		var s: Node = (load(fp) as PackedScene).instantiate()
		var stack := [s]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				for i in n.mesh.get_surface_count():
					var ov: Material = n.get_surface_override_material(i)
					var desc := "NO OVERRIDE"
					if ov != null:
						desc = ov.resource_path.get_file()
						if ov is StandardMaterial3D:
							desc += " tex=" + str(ov.albedo_texture != null)
					print("PROBE %s surf %d: %s" % [fp.get_file(), i, desc])
			for c in n.get_children():
				stack.append(c)
		s.free()
	quit()
