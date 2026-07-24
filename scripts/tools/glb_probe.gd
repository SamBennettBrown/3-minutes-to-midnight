extends SceneTree

# Probe the Blender-converted run animation for arm motion.


func _init() -> void:
	var pack: PackedScene = load("res://scripts/tools/converted/run_f.glb")
	if pack == null:
		print("PROBE: glb failed to load")
		quit()
		return
	var inst := pack.instantiate()
	var player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if player == null or skels.is_empty():
		print("PROBE: incomplete glb scene")
		quit()
		return
	var sk: Skeleton3D = skels[0]
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		print("PROBE clip '%s' tracks=%d length=%.2f" % [anim_name, anim.get_track_count(), anim.length])
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(anim.track_get_path(i).get_concatenated_subnames())
			if bone in ["Shoulder_L", "Elbow_L", "Hand_L", "UpperLeg_R", "LowerLeg_R", "Hips", "Spine_01"]:
				var keys := anim.track_get_key_count(i)
				var q0: Quaternion = anim.track_get_key_value(i, 0)
				var qm: Quaternion = anim.track_get_key_value(i, keys / 2)
				var bi := sk.find_bone(bone)
				var rest := sk.get_bone_rest(bi).basis.get_rotation_quaternion() if bi != -1 else Quaternion.IDENTITY
				print("PROBE %s: keys=%d spread=%.1f offset_from_rest=%.1f" % [bone, keys,
						rad_to_deg((q0.inverse() * qm).get_angle()),
						rad_to_deg((rest.inverse() * q0).get_angle())])
	quit()
