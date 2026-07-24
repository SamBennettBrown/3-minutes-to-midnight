extends Node

# Diagnostic tour: teleport the player through bullpen -> evidence ->
# boss office, capturing each room's camera to inspect visuals.

const STOPS := [
	{"t": 2.0, "pos": Vector3(0, 0, 1.5)},      # bullpen west shot
	{"t": 4.0, "pos": Vector3(0, 0, -10)},      # evidence
	{"t": 6.0, "pos": Vector3(17.5, 0, 0)},     # hall 2
]
const CAPTURE_TIMES := [3.0, 5.0, 7.0]

var _t := 0.0
var _captured := 0
var _stop_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	DirAccess.make_dir_recursive_absolute("res://scripts/tools/frames")


func _process(_delta: float) -> void:
	_t += _delta
	# skip the intro dialogues instantly so rooms behave normally
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and dlg.visible:
		dlg._text.visible_characters = -1
		dlg._index = 999
		dlg.visible = false
		get_tree().paused = false
	if _stop_i < STOPS.size() and _t >= STOPS[_stop_i]["t"]:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			p.global_position = STOPS[_stop_i]["pos"]
		_stop_i += 1
	if _captured < CAPTURE_TIMES.size() and _t >= CAPTURE_TIMES[_captured]:
		get_viewport().get_texture().get_image().save_png("res://scripts/tools/frames/world_%d.png" % _captured)
		_captured += 1
		if _captured >= CAPTURE_TIMES.size():
			get_tree().quit()
