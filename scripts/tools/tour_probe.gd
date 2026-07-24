extends Node

# Room tour: skip the intro, teleport the player to every room center,
# capture each room camera to frames/tour_<name>.png.

const Flags := preload("res://scripts/game/flags.gd")

const STOPS := [
	["bullpen_west", Vector3(-5, 0, 1)],
	["bullpen_east", Vector3(5, 0, 1)],
	["lobby", Vector3(0, 0, 10)],
	["captains", Vector3(-10, 0, -10)],
	["evidence", Vector3(0, 0, -10)],
	["hall1", Vector3(7, 0, -12)],
	["observation", Vector3(-1, 0, -27.5)],
	["hall2", Vector3(17.5, 0, 0)],
	["locker", Vector3(15, 0, 7)],
	["range", Vector3(15, 0, -7)],
	["cells", Vector3(27, 0, 0)],
]

var _t := 0.0
var _i := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Flags.set_flag("intro_done")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	DirAccess.make_dir_recursive_absolute("res://scripts/tools/frames")


func _process(_delta: float) -> void:
	_t += _delta
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and dlg.visible:
		dlg.visible = false
		get_tree().paused = false
	var step := int(_t / 1.2)
	if step > _i:
		if _i >= 0 and _i < STOPS.size():
			get_viewport().get_texture().get_image().save_png(
					"res://scripts/tools/frames/tour_%s.png" % STOPS[_i][0])
		if step >= STOPS.size():
			get_tree().quit()
			return
		_i = step
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			p.global_position = STOPS[_i][1]
