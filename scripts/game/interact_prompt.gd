extends Label3D

const Tuning := preload("res://scripts/game/tuning.gd")
const Interact := preload("res://scripts/game/interact.gd")

# Interact cue ("E") floating over the nearest interactable in range.
# Runs after everyone else has moved (process_priority) so it never
# lags a frame behind a walking NPC. Each target can set its own
# `prompt_height` (folders sit low, heads sit high). Hidden while
# dialogue is open.

@export var prompt_range := Tuning.INTERACT_RANGE
@export var default_height := 2.05


func _ready() -> void:
	process_priority = 100


func _process(_delta: float) -> void:
	var body := get_parent() as Node3D
	if body == null:
		return
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg != null and dlg.visible:
		visible = false
		return
	var nearest := Interact.nearest(get_tree(), body.global_position, prompt_range)
	if nearest == null:
		visible = false
		return
	var h := default_height
	var ph = nearest.get("prompt_height")
	if ph != null:
		h = float(ph)
	var bob := sin(Time.get_ticks_msec() * 0.004) * 0.06
	global_position = nearest.global_position + Vector3(0, h + bob, 0)
	visible = true
