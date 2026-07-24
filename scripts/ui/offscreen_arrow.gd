extends CanvasLayer

# Screen-edge arrow pointing at the player whenever the live camera
# doesn't have them in frame (door transitions, odd corners). White
# low-poly triangle, clamped inside a margin, aimed at the player.

@export var margin := 60.0

var _arrow: Polygon2D


func _ready() -> void:
	layer = 101
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([
		Vector2(24, 0), Vector2(-14, -15), Vector2(-14, 15),
	])
	_arrow.color = Color(0.95, 0.95, 0.93)
	_arrow.visible = false
	add_child(_arrow)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if cam == null or player == null:
		_arrow.visible = false
		return
	var target := player.global_position + Vector3(0, 1.2, 0)
	if cam.is_position_in_frustum(target):
		_arrow.visible = false
		return
	# on the camera's own plane, unproject is degenerate - skip the frame
	var cam_local := cam.global_transform.affine_inverse() * target
	if absf(cam_local.z) < 0.05:
		_arrow.visible = false
		return
	var screen := get_viewport().get_visible_rect().size
	var center := screen * 0.5
	var dir := cam.unproject_position(target) - center
	if cam.is_position_behind(target):
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var half := center - Vector2(margin, margin)
	var kx := INF if absf(dir.x) < 0.0001 else half.x / absf(dir.x)
	var ky := INF if absf(dir.y) < 0.0001 else half.y / absf(dir.y)
	_arrow.position = center + dir * minf(kx, ky)
	_arrow.rotation = dir.angle()
	_arrow.visible = true
