extends Node3D

# End-to-end booth verification: instantiate the ACTUAL ModelBillboard
# (same code path the game uses), point a camera at its sprite, and
# capture frames spread across the clip to prove visible motion.

const CAPTURE_FRAMES := [40, 90, 140, 190]

var _frame := 0
var _captured := 0


func _ready() -> void:
	var bb: Node3D = load("res://sprites/model_billboard.tscn").instantiate()
	bb.model_path = "res://scripts/tools/retarget/butcher_rt.glb"
	bb.anim_path = "res://scripts/tools/retarget/walk_rt.glb"
	add_child(bb)

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.0, 3.0)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.24, 0.3)
	env.environment = e
	add_child(env)
	DirAccess.make_dir_recursive_absolute("res://scripts/tools/frames")


func _process(_delta: float) -> void:
	_frame += 1
	if _captured < CAPTURE_FRAMES.size() and _frame == CAPTURE_FRAMES[_captured]:
		get_viewport().get_texture().get_image().save_png("res://scripts/tools/frames/booth_%d.png" % _captured)
		_captured += 1
		if _captured >= CAPTURE_FRAMES.size():
			get_tree().quit()

