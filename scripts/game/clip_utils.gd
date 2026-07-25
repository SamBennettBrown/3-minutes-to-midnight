# Animation-clip processing for the Synty pipeline. Static helpers -
# no state. Used by the character rig; safe anywhere.
#
#   const ClipUtils := preload("res://scripts/game/clip_utils.gd")


# Every Synty clip opens with a T-pose calibration frame, which causes
# a visible hitch when the loop wraps - trim the first `trim` seconds.
static func prep_clip(anim: Animation, trim := 0.1) -> void:
	for i in anim.get_track_count():
		for k in range(anim.track_get_key_count(i) - 1, -1, -1):
			if anim.track_get_key_time(i, k) < trim:
				anim.track_remove_key(i, k)
		for k in anim.track_get_key_count(i):
			anim.track_set_key_time(i, k, anim.track_get_key_time(i, k) - trim)
	anim.length = maxf(anim.length - trim, 0.1)
	anim.loop_mode = Animation.LOOP_LINEAR


# Pin the hips' TRAVEL so a clip plays in place at a constant height - for
# characters whose position is driven externally (player, scheduled NPCs).
# We flatten ALL three axes to the first frame: X/Z so it doesn't drift,
# and Y so the vertical hip bob can't push the planted foot through the
# floor (or leave the character floating) at the extremes of the cycle.
# Grounding then depends only on the static foot_offset, which can be
# tuned once instead of fighting a moving low-point every stride.
static func strip_root_motion(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(anim.track_get_path(i))
		if not (path.ends_with("Hips") or path.ends_with("Root")):
			continue
		if anim.track_get_key_count(i) == 0:
			continue
		var first: Vector3 = anim.track_get_key_value(i, 0)
		for k in anim.track_get_key_count(i):
			anim.track_set_key_value(i, k, first)


# Rest height of the hips - used to normalize GLB scale (aim ~0.95m).
static func hips_height(skel: Skeleton3D) -> float:
	var hips := skel.find_bone("Hips")
	if hips == -1:
		hips = skel.find_bone("Pelvis")
	if hips == -1:
		return 0.0
	var xf := Transform3D.IDENTITY
	var b := hips
	while b != -1:
		xf = skel.get_bone_rest(b) * xf
		b = skel.get_bone_parent(b)
	return absf(xf.origin.y)
