extends SceneTree

# Check the lean idle has live keys after disabling immutable-track removal.


func _init() -> void:
	var pack: PackedScene = load("res://scripts/tools/retarget/walk_rt.glb")
	var inst := pack.instantiate()
	var player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var anim := player.get_animation(player.get_animation_list()[0])
	print("PROBE walk length=%.2f tracks=%d" % [anim.length, anim.get_track_count()])
	for i in mini(anim.get_track_count(), 30):
		if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(anim.track_get_path(i).get_concatenated_subnames())
		if bone in ["Spine", "Chest", "Head", "LeftUpperArm", "Hips"]:
			var keys := anim.track_get_key_count(i)
			var q0: Quaternion = anim.track_get_key_value(i, 0)
			var qq: Quaternion = anim.track_get_key_value(i, keys / 4 * 1)
			print("PROBE %s keys=%d quarter-diff=%.2f deg" % [bone, keys,
					rad_to_deg((q0.inverse() * qq).get_angle())])
	inst.free()
	quit()



