extends StaticBody3D

# One evidence shelf you can shove aside. Interact to slide it along its
# local X by `slide_by`; interact again to slide it back. The collider is
# a child of THIS StaticBody, so it rides along - a shelf parked in front
# of the weight plate physically blocks you until you move it out of the
# way.
#
# Collision is generated from the shelf meshes at _ready (like the Props
# auto-collider, but the boxes are OUR children so they move with us).

const Sfx := preload("res://scripts/game/sfx.gd")

## how far (local X metres) the shelf slides when shoved
@export var slide_by := 1.3
@export var slide_time := 0.7
@export var prompt_height := 1.4
## smallest mesh footprint (m) that still gets a collider
@export var min_footprint := 0.35
@export var min_height := 0.25

var _home := Vector3.ZERO
var _out := false
var _moving := false


func _ready() -> void:
	add_to_group("talkable")
	_home = position
	_build_collision()


# snug box colliders for every sizeable mesh under us - parented to this
# StaticBody so they translate when the shelf slides
func _build_collision() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = m.get_aabb()
		if aabb.size.x < min_footprint and aabb.size.z < min_footprint:
			continue
		if aabb.size.y < min_height:
			continue
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size * Vector3(0.82, 1.0, 0.82)
		cs.shape = box
		# express the mesh's AABB centre in OUR local space (meshes may be
		# nested a few levels down), so the box lands on the mesh
		var rel: Transform3D = global_transform.affine_inverse() * m.global_transform
		cs.position = rel * aabb.get_center()
		add_child(cs)


func interact() -> void:
	if _moving:
		return
	_out = not _out
	var target := _home + Vector3(slide_by if _out else 0.0, 0.0, 0.0)
	Sfx.play_at(self, "res://audio/sfx/door_close.mp3", -18.0)
	_moving = true
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "position", target, slide_time)
	tw.tween_callback(func() -> void: _moving = false)
