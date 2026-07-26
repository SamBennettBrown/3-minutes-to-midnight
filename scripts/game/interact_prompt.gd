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

var _target: Node3D
# world-space offset from the target's origin to its VISUAL centre, cached
# per target. FBX prop origins often sit at a corner of the mesh, which
# parked the E off to one side of the lockers - and each wall's rotation
# pushed it a different way. Characters keep their origin (feet), which is
# already centred.
var _anchor_offset := Vector3.ZERO
# the current target PROP glows softly - the E floats near the player, so
# the glow is what says exactly WHICH thing you're on. Characters skip it
# (a glowing person reads wrong; people are obviously talkable).
var _hl_mat: StandardMaterial3D
var _hl_meshes: Array = []


func _ready() -> void:
	process_priority = 100
	_hl_mat = StandardMaterial3D.new()
	_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hl_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# a faint BLOOD-warm wash - reads even through the mono grade
	_hl_mat.albedo_color = Color(0.1, 0.035, 0.03)


func _set_highlight(n: Node3D) -> void:
	_clear_highlight()
	if n == null or n.has_method("get_conversation"):
		return
	# some interactables (the vending machine) are bare logic nodes whose
	# visible prop lives elsewhere - follow their machine_path to the meshes
	var vis: Node = n
	if "machine_path" in n:
		var prop: Node = n.get_node_or_null(n.machine_path)
		if prop != null:
			vis = prop
	for m in vis.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _hl_mat
		_hl_meshes.append(m)


func _clear_highlight() -> void:
	for m in _hl_meshes:
		if is_instance_valid(m):
			m.material_overlay = null
	_hl_meshes.clear()


func _compute_anchor_offset(n: Node3D) -> Vector3:
	if n.has_method("get_conversation"):
		return Vector3.ZERO  # a character - origin is fine
	var center := Vector3.ZERO
	var count := 0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		center += m.global_transform * m.get_aabb().get_center()
		count += 1
	if count == 0:
		return Vector3.ZERO
	center /= count
	# XZ only - height still comes from the origin + prompt_height
	var off := center - n.global_position
	off.y = 0.0
	return off


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
		_clear_highlight()
		# fade OUT instead of popping off
		modulate.a = maxf(modulate.a - _delta / 0.1, 0.0)
		if modulate.a <= 0.0:
			visible = false
			_target = null
		return
	# STICKY target: when several interactables are packed together (the wall
	# lockers), don't let the prompt jitter between them as you shuffle. Keep
	# the current one until it's clearly out of range or another is much
	# closer, so the E sits still instead of jumping "all over the place".
	if _target != null and is_instance_valid(_target) and _target.is_in_group("talkable"):
		var d_cur: float = body.global_position.distance_to(_target.global_position)
		var d_new: float = body.global_position.distance_to(nearest.global_position)
		if d_cur <= prompt_range and d_cur <= d_new + 0.6:
			nearest = _target
	if nearest != _target:
		_anchor_offset = _compute_anchor_offset(nearest)
		_set_highlight(nearest)
	elif _target != null and _anchor_offset == Vector3.ZERO and not nearest.has_method("get_conversation"):
		# same target but offset never resolved (meshes may load a frame late)
		_anchor_offset = _compute_anchor_offset(nearest)
	_target = nearest
	var h := default_height
	var ph = nearest.get("prompt_height")
	if ph != null:
		h = float(ph)
	# the glow breathes with the E's bob so they read as one signal
	_hl_mat.albedo_color = Color(0.1, 0.035, 0.03) \
			* (0.8 + 0.35 * sin(Time.get_ticks_msec() * 0.004))
	var bob := sin(Time.get_ticks_msec() * 0.004) * 0.06
	# snap straight onto the target every frame. (An earlier lerp here fought
	# the player's own motion - the prompt is parented to the player, so
	# smoothing toward a world goal while the body moves reads as violent
	# jitter. A direct set is rock-steady.)
	var pos := nearest.global_position + _anchor_offset + Vector3(0, h + bob, 0)
	# big props (the evidence shelves especially): the mesh centre sits DEEP
	# inside the model, which parks the E awkwardly in the shelving. Pull it
	# toward the player so it floats off the prop's face instead.
	if not nearest.has_method("get_conversation"):
		var pull := body.global_position - pos
		pull.y = 0.0
		var d := pull.length()
		if d > 0.01:
			pos += pull / d * minf(0.55, d * 0.4)
	global_position = pos
	# fade IN over ~0.1s - kills the last spreadsheet-UI pop
	if not visible:
		modulate.a = 0.0
	visible = true
	modulate.a = minf(modulate.a + _delta / 0.1, 1.0)
