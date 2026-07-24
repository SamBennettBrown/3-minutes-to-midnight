@tool
extends Label3D

# Stencil text painted on the floor. It ALWAYS lies flat - duplicate
# the node, change the text, drag it into place, and spin yaw_degrees
# in the Inspector. Runs in the editor too, so what you see in the
# viewport IS how it looks in game; rotation-gizmo and scale accidents
# are corrected the moment they happen.

## rotation of the text on the floor plane
@export var yaw_degrees := -30.0:
	set(v):
		yaw_degrees = v
		_flatten()


func _ready() -> void:
	_flatten()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_flatten()


func _flatten() -> void:
	rotation_degrees = Vector3(-90.0, yaw_degrees, 0.0)
	scale = Vector3.ONE
	position.y = 0.02
