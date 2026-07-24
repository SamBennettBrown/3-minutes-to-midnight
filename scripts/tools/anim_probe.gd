extends SceneTree

# Headless probe: dissect the imported run animation and the mannequin
# skeleton. Run:  godot --headless -s res://scripts/tools/anim_probe.gd

const ANIM := "res://ANIMATION_Base_Locomotion_SourceFiles_v3/SourceFiles/Animations/Polygon/Masculine/Locomotion/Run/A_Run_F_Masc.fbx"
const MODEL := "res://ANIMATION_Base_Locomotion_SourceFiles_v3/SourceFiles/Character/PolygonSyntyCharacter.fbx"


func _init() -> void:
	var pack: PackedScene = load(ANIM)
	if pack == null:
		print("PROBE: anim failed to load")
		quit()
		return
	var inst := pack.instantiate()
	var player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	print("PROBE: anim scene skeletons: ", skels.size())
	if not skels.is_empty():
		var sk: Skeleton3D = skels[0]
		var names := PackedStringArray()
		for b in sk.get_bone_count():
			names.append(sk.get_bone_name(b))
		print("PROBE: anim rig bones (%d): %s" % [names.size(), ", ".join(names)])
	if player:
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			print("PROBE: clip '%s' tracks=%d length=%.2f" % [anim_name, anim.get_track_count(), anim.length])
			for i in anim.get_track_count():
				var t := anim.track_get_type(i)
				var path := anim.track_get_path(i)
				var keys := anim.track_get_key_count(i)
				var spread := ""
				if t == Animation.TYPE_ROTATION_3D and keys > 2:
					var q0: Quaternion = anim.track_get_key_value(i, 0)
					var qm: Quaternion = anim.track_get_key_value(i, keys / 2)
					spread = " spread=%.1fdeg" % rad_to_deg((q0.inverse() * qm).get_angle())
				print("PROBE:   [%d] type=%d keys=%d %s%s" % [i, t, keys, path, spread])
	inst.free()

	var mpack: PackedScene = load(MODEL)
	if mpack:
		var minst := mpack.instantiate()
		var mskels := minst.find_children("*", "Skeleton3D", true, false)
		if not mskels.is_empty():
			var msk: Skeleton3D = mskels[0]
			var mnames := PackedStringArray()
			for b in msk.get_bone_count():
				mnames.append(msk.get_bone_name(b))
			print("PROBE: model bones (%d): %s" % [mnames.size(), ", ".join(mnames)])
		minst.free()
	quit()
