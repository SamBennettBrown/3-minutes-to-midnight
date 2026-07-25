extends Node

# The impossible death, witnessed. This is the DISCOVERY that turns the
# player's own instinct ("I'll just wait in the cells at midnight") into the
# key clue instead of a dead end.
#
# If the player is standing in the CELLS in the final seconds (~2:50-3:00)
# the FIRST time, they see it up close: a muzzle-flash from INSIDE THE WALL,
# the witness drops, and they couldn't stop it - the shooter is behind solid
# concrete. Sets `saw_wall_shot` and a journal beat pointing at the passage.
#
# This does NOT stop the loop (the murder still happens; the night still
# resets at 0:00). Stopping it is the endgame (endgame_director.gd), which
# needs the proof and happens on the captain's side, in the locker room.
#
# Placed as a child of the Cells room scene so it finds the room by walking
# up to its parent; falls back to the "Cells" room node by name.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

## the shot lands AT midnight (0:00 = t180). You must be in the cells in the
## final moments to witness it - firing at ~179 so it reads as "at midnight",
## not 10 seconds early. window_end guards the upper edge.
@export var window_start := 178.5
@export var window_end := 180.0
## how far into the wall the flash appears to come from (local, informational)
@export var shot_sound := "res://audio/sfx/gun_fire.mp3"
@export var shot_volume_db := -8.0

var _clock: Node
var _cells: Node3D
var _flash: CanvasLayer
var _rect: ColorRect
var _fired := false


func _enter_tree() -> void:
	add_to_group("cell_murder")


func _ready() -> void:
	# a thin white flash layer for the muzzle burst
	_flash = CanvasLayer.new()
	_flash.layer = 110
	_flash.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_flash)
	_rect = ColorRect.new()
	_rect.color = Color(1, 1, 1, 0)
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.add_child(_rect)


func _process(_delta: float) -> void:
	if _fired or Flags.has_flag("saw_wall_shot"):
		return
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		if _clock == null:
			return
	if _clock.time < window_start or _clock.time > window_end:
		return
	# must be physically in the cells to witness it up close
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if _cells == null:
		_cells = _find_cells()
	if _cells == null or not _cells.contains_point(player.global_position, 0.0):
		return
	_fired = true
	_reveal()


func _reveal() -> void:
	Flags.set_flag("saw_wall_shot")
	# the muzzle-flash from inside the wall. NO gunshot sfx here - the loop's
	# own restart plays THE shot (lose_screen), so the murder is a single
	# gunshot at 0:00, not two. We just add the flash + the realisation.
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_rect, "color:a", 0.9, 0.05)
	tw.tween_property(_rect, "color:a", 0.0, 0.5)
	# the realisation - shown as narration (pauses the tree, so the loop's
	# t180 auto-restart waits until the player reads it, then fires the shot)
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and not dlg.visible:
		dlg.show_dialogue([
			{"speaker": "DETECTIVE", "text": "The flash - it came from the WALL. Right through solid concrete, and he's down. I was standing RIGHT HERE."},
			{"speaker": "DETECTIVE", "text": "Nobody in here but the prisoner, and she never moved. There's a way into this block I can't see. Behind the wall. I have to find it."},
		])


func _find_cells() -> Node3D:
	# prefer the room this node lives under
	var p := get_parent()
	while p != null:
		if p.is_in_group("room") and String(p.name) == "Cells":
			return p as Node3D
		p = p.get_parent()
	for r in get_tree().get_nodes_in_group("room"):
		if String(r.name) == "Cells":
			return r as Node3D
	return null
