extends Node
const Flags := preload("res://scripts/game/flags.gd")
var _t := 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Flags.set_flag("intro_done")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
func _process(delta: float) -> void:
	_t += delta
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and dlg.visible:
		dlg.visible = false
		get_tree().paused = false
	if _t > 2.0 and _t < 2.1:
		var obs: Node3D = null
		for r in get_tree().get_nodes_in_group("room"):
			if String(r.name) == "Observation":
				obs = r
		if obs != null:
			obs.activate()
			var cam := Camera3D.new()
			add_child(cam)
			cam.fov = 45.0
			var pos: Vector3 = obs.to_global(Vector3(0, 2.1, 0.9))
			cam.look_at_from_position(pos, Vector3(2.5, 1.2, -23.6))
			cam.make_current()
		_t = 2.2
	if _t > 3.2:
		get_viewport().get_texture().get_image().save_png("res://scripts/tools/frames/glass.png")
		get_tree().quit()
