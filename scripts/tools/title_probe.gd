extends Node

# Diagnostic: boot the title screen, capture frames, then press START
# and capture the world after the blackout hand-off.

var _t := 0.0
var _captured_title := false
var _started := false
var _captured_world := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var title: Node = load("res://scenes/title_screen.tscn").instantiate()
	add_child(title)
	DirAccess.make_dir_recursive_absolute("res://scripts/tools/frames")


func _process(delta: float) -> void:
	_t += delta
	if not _captured_title and _t >= 1.5:
		get_viewport().get_texture().get_image().save_png("res://scripts/tools/frames/title_0.png")
		_captured_title = true
	if not _started and _t >= 2.0:
		_started = true
		var title := get_child(0)
		if title.has_method("blackout"):
			await title.blackout()
		title.queue_free()
		var world: Node = load("res://scenes/world.tscn").instantiate()
		add_child(world)
	if _started and not _captured_world and _t >= 6.5:
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null and dlg.visible:
			dlg.visible = false
			get_tree().paused = false
		get_viewport().get_texture().get_image().save_png("res://scripts/tools/frames/title_1_world.png")
		_captured_world = true
		get_tree().quit()
