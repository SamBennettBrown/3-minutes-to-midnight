extends Node3D

# Drop this on any dressing container (a "Props" node): every mesh
# underneath gets a snug invisible box collider at runtime. Desks and
# cabinets block feet; small desk clutter (mice, pencils, paper) is
# skipped so it stays walk-past-able.

## smallest footprint (m) that still gets a collider
@export var min_footprint := 0.35
## flatter than this (m) is desk clutter, not furniture
@export var min_height := 0.25
## boxes are slimmed to this fraction of the mesh footprint - full-size
## boxes catch shoulders on every corner and wedge people in doorways
@export var shrink := 0.82


func _ready() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = m.get_aabb()
		if aabb.size.x < min_footprint and aabb.size.z < min_footprint:
			continue
		if aabb.size.y < min_height:
			continue
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size * Vector3(shrink, 1.0, shrink)
		cs.shape = box
		cs.position = aabb.get_center()
		body.add_child(cs)
		m.add_child(body)
