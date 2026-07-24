extends SceneTree

# Scrub the Blender-converted run and measure global travel of the left
# hand vs the right foot. The honest test of "do the arms animate."

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var pack: PackedScene = load("res://scripts/tools/converted/run_f.glb")
	var inst := pack.instantiate()
	root.add_child(inst)
	var player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var anim_name: String = player.get_animation_list()[0]
	player.play(anim_name)
	var hand := sk.find_bone("Hand_L")
	var foot := sk.find_bone("Foot_R")
	var hips := sk.find_bone("Hips")
	var hand_min := Vector3.INF
	var hand_max := -Vector3.INF
	var foot_min := Vector3.INF
	var foot_max := -Vector3.INF
	for step in 15:
		var t := 0.7 * step / 14.0
		player.seek(t, true)
		var hips_pos := sk.get_bone_global_pose(hips).origin
		var hand_pos := sk.get_bone_global_pose(hand).origin - hips_pos
		var foot_pos := sk.get_bone_global_pose(foot).origin - hips_pos
		hand_min = hand_min.min(hand_pos)
		hand_max = hand_max.max(hand_pos)
		foot_min = foot_min.min(foot_pos)
		foot_max = foot_max.max(foot_pos)
	print("PROBE hand travel (m): ", hand_max - hand_min)
	print("PROBE foot travel (m): ", foot_max - foot_min)
	return true
