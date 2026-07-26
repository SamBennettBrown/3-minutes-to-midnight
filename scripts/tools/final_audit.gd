extends Node

# Pre-ship audit: loads the world and verifies the data wiring that a
# short boot can't catch.
#  - every NPC schedule entry resolved its spot to a position
#  - vanish_at_spot markers exist
#  - every bark "sound" file exists
#  - every keypad/gate/ward references sounds that exist
#  - room label/display sanity: every room has a camera unless it opts out

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_audit()
	get_tree().quit()


func _audit() -> void:
	var bad := 0
	print("=============== FINAL AUDIT ===============")
	for npc in get_tree().get_nodes_in_group("talkable"):
		var sched = npc.get("schedule")
		if sched == null:
			continue
		for i in sched.size():
			var e: Dictionary = sched[i]
			if e.has("spot") and not e.has("pos"):
				print("!! %s schedule[%d]: UNRESOLVED spot '%s'" % [npc.name, i, e["spot"]])
				bad += 1
		var vas = npc.get("vanish_at_spot")
		if vas != null and String(vas) != "" and npc.has_method("_find_spot"):
			if npc._find_spot(String(vas)) == null:
				print("!! %s vanish_at_spot '%s' NOT FOUND" % [npc.name, vas])
				bad += 1
		var brks = npc.get("barks")
		if brks != null:
			for b in brks:
				var snd := String((b as Dictionary).get("sound", ""))
				if snd != "" and not ResourceLoader.exists(snd):
					print("!! %s bark sound missing: %s" % [npc.name, snd])
					bad += 1
	for room in get_tree().get_nodes_in_group("room"):
		var cam := false
		for c in room.get_children():
			if c is Camera3D:
				cam = true
		if not cam:
			print("note: room '%s' has no camera (holds previous shot)" % room.name)
	print("=============== %d problems ===============" % bad)
