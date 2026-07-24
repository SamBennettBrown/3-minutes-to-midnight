extends SceneTree

# Compare the RAW (unretargeted) run animation against the normalized one:
# arm channel spread + first-key value vs the rig's rest, per arm bone.

const RAW_ANIM := "res://scripts/tools/raw/raw_run.fbx"
const NORM_ANIM := "res://ANIMATION_Base_Locomotion_SourceFiles_v3/SourceFiles/Animations/Polygon/Masculine/Locomotion/Run/A_Run_F_Masc.fbx"


func _init() -> void:
	_probe("RAW", RAW_ANIM, ["Shoulder_L", "Elbow_L", "UpperLeg_R"])
	_probe("NORM", NORM_ANIM, ["LeftUpperArm", "LeftLowerArm", "RightUpperLeg"])
	quit()


func _probe(label: String, path: String, bones: Array) -> void:
	var pack: PackedScene = load(path)
	if pack == null:
		print("PROBE %s: failed to load" % label)
		return
	var inst := pack.instantiate()
	var player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if player == null or skels.is_empty() or player.get_animation_list().is_empty():
		print("PROBE %s: incomplete scene" % label)
		inst.free()
		return
	var sk: Skeleton3D = skels[0]
	var anim := player.get_animation(player.get_animation_list()[0])
	for bone_name in bones:
		var bi := sk.find_bone(bone_name)
		var rest := Quaternion.IDENTITY
		if bi != -1:
			rest = sk.get_bone_rest(bi).basis.get_rotation_quaternion()
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			if String(anim.track_get_path(i).get_concatenated_subnames()) != bone_name:
				continue
			var keys := anim.track_get_key_count(i)
			var q0: Quaternion = anim.track_get_key_value(i, 0)
			var qm: Quaternion = anim.track_get_key_value(i, keys / 2)
			print("PROBE %s %s: keys=%d spread=%.1f  offset_from_rest=%.1f deg" % [
					label, bone_name, keys,
					rad_to_deg((q0.inverse() * qm).get_angle()),
					rad_to_deg((rest.inverse() * q0).get_angle())])
	inst.free()
