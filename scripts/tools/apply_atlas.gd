@tool
extends EditorScenePostImport

# Post-import hook: stamps the right Synty atlas material onto every
# mesh surface of an imported FBX, picked by which pack it lives in.
# Wired into the .import files of the pack folders - any FBX imported
# from them arrives textured, no manual material dragging.

const MATS := {
	"POLYGON_Police_Station": "res://materials/police_props.tres",
	"POLYGON_Office": "res://materials/office_props.tres",
}


func _post_import(scene: Node) -> Object:
	var src := get_source_file()
	for key in MATS:
		if key in src:
			_apply(scene, load(MATS[key]))
			break
	return scene


const SCREEN_MAT := "res://materials/screen_dark.tres"
const SCREEN_WORDS := ["screen", "glass", "emissive", "monitor", "display"]


func _apply(node: Node, mat: Material) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():
			# screens/glass use their own UV space - the atlas turns them
			# into noise. Give them a quiet dark emissive instead.
			var orig: Material = mesh.surface_get_material(i)
			var orig_name: String = orig.resource_name.to_lower() if orig != null else ""
			var is_screen := false
			for w in SCREEN_WORDS:
				if String(w) in orig_name:
					is_screen = true
					break
			node.set_surface_override_material(i, load(SCREEN_MAT) if is_screen else mat)
	for c in node.get_children():
		_apply(c, mat)
