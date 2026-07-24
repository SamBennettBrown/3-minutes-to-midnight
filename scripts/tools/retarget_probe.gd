extends SceneTree

# The decisive test: play the retargeted idle on the retargeted ork's OWN
# skeleton (own mesh, own skins - no dressing). Measure real motion.

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var ork: Node3D = (load("res://scripts/tools/retarget/ork_rt.glb") as PackedScene).instantiate()
	root.add_child(ork)
	var sk: Skeleton3D = ork.find_children("*", "Skeleton3D", true, false)[0]
	print("PROBE ork skeleton node: ", sk.name)
	var sample := PackedStringArray()
	for b in mini(sk.get_bone_count(), 12):
		sample.append(sk.get_bone_name(b))
	print("PROBE ork bones: ", ", ".join(sample))

	var idle: Node3D = (load("res://scripts/tools/retarget/idle_rt.glb") as PackedScene).instantiate()
	var src: AnimationPlayer = idle.find_child("AnimationPlayer", true, false)
	if src == null or src.get_animation_list().is_empty():
		print("PROBE idle has no clips")
		return true
	var anim_name: String = src.get_animation_list()[0]
	var anim: Animation = src.get_animation(anim_name)
	print("PROBE idle clip: %s, sample paths:" % anim_name)
	for i in mini(anim.get_track_count(), 4):
		print("PROBE   ", anim.track_get_path(i))
	idle.free()

	var player := AnimationPlayer.new()
	ork.add_child(player)
	var lib := AnimationLibrary.new()
	lib.add_animation("test", anim)
	player.add_animation_library("t", lib)
	player.play("t/test")

	var hand := sk.find_bone("LeftHand")
	var head := sk.find_bone("Head")
	if hand == -1 or head == -1:
		print("PROBE VERDICT: retarget did not rename ork bones -> FAILED")
		return true
	var hand_min := Vector3.INF
	var hand_max := -Vector3.INF
	var head_min := Vector3.INF
	var head_max := -Vector3.INF
	for step in 12:
		player.seek(anim.length * step / 11.0, true)
		var hips_pos := sk.get_bone_global_pose(sk.find_bone("Hips")).origin
		var hp := sk.get_bone_global_pose(hand).origin - hips_pos
		var dp := sk.get_bone_global_pose(head).origin - hips_pos
		hand_min = hand_min.min(hp)
		hand_max = hand_max.max(hp)
		head_min = head_min.min(dp)
		head_max = head_max.max(dp)
	print("PROBE hand sway: ", (hand_max - hand_min).length())
	print("PROBE head sway: ", (head_max - head_min).length())
	print("PROBE head height above hips at end: ", head_max.y)
	return true
