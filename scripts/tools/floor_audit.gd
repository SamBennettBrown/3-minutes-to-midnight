extends Node

# Headless audit of room footprints. For every room in the "room" group:
#  - each FLOOR collider's world-space XZ rect (what claims the player)
#  - the floor MESH's world-space XZ rect (what the player actually sees)
#  - flags colliders that overhang their own mesh (claims void)
# Then pairwise between rooms: floor-vs-floor overlaps (double-claim zones)
# and the gap width between nearby floors (dead strips where no room claims).

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	_audit()
	get_tree().quit()


# world-space XZ rect of a BoxShape3D collider
func _shape_rect(cs: CollisionShape3D) -> Rect2:
	var box := cs.shape as BoxShape3D
	if box == null:
		return Rect2()
	var he := box.size * 0.5
	var r := Rect2(Vector2.INF, Vector2.ZERO)
	var first := true
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := cs.global_transform * Vector3(he.x * sx, 0.0, he.z * sz)
			var v := Vector2(p.x, p.z)
			if first:
				r = Rect2(v, Vector2.ZERO)
				first = false
			else:
				r = r.expand(v)
	return r


# world-space XZ rect of every mesh under a node
func _mesh_rect(n: Node) -> Rect2:
	var r := Rect2()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = m.global_transform * m.get_aabb()
		var lo := Vector2(aabb.position.x, aabb.position.z)
		var hi := Vector2(aabb.end.x, aabb.end.z)
		if first:
			r = Rect2(lo, hi - lo)
			first = false
		else:
			r = r.expand(lo).expand(hi)
	return r


func _fmt(r: Rect2) -> String:
	return "x[%.2f..%.2f] z[%.2f..%.2f]" % [r.position.x, r.end.x, r.position.y, r.end.y]


func _audit() -> void:
	var rooms: Array = get_tree().get_nodes_in_group("room")
	var floors := {}  # room name -> Array[Rect2]
	print("=================== FLOOR AUDIT ===================")
	for room in rooms:
		var rects: Array = []
		print("\n## %s" % room.name)
		for cs in room.find_children("*", "CollisionShape3D", true, false):
			var parent: Node = cs.get_parent()
			if parent == null or not ("Floor" in String(parent.name)):
				continue
			var col := _shape_rect(cs)
			rects.append(col)
			var mesh := _mesh_rect(parent)
			print("  collider %-28s %s" % [String(parent.name) + "/" + String(cs.name), _fmt(col)])
			if mesh.size != Vector2.ZERO:
				print("  mesh     %-28s %s" % ["", _fmt(mesh)])
				var over_l := mesh.position.x - col.position.x
				var over_r := col.end.x - mesh.end.x
				var over_t := mesh.position.y - col.position.y
				var over_b := col.end.y - mesh.end.y
				var worst := maxf(maxf(over_l, over_r), maxf(over_t, over_b))
				if worst > 0.15:
					print("  !! COLLIDER OVERHANGS MESH by up to %.2f m  (W:%.2f E:%.2f N:%.2f S:%.2f)"
							% [worst, over_l, over_r, over_t, over_b])
		floors[String(room.name)] = rects
	print("\n=================== PAIRWISE ===================")
	var names: Array = floors.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			for ra in floors[names[i]]:
				for rb in floors[names[j]]:
					var inter: Rect2 = (ra as Rect2).intersection(rb)
					if inter.size.x > 0.05 and inter.size.y > 0.05:
						print("OVERLAP  %-14s x %-14s  %s  (%.2f x %.2f m)"
								% [names[i], names[j], _fmt(inter), inter.size.x, inter.size.y])
					else:
						# gap between near-adjacent floors along their facing edges
						var gx := maxf((rb as Rect2).position.x - (ra as Rect2).end.x,
								(ra as Rect2).position.x - (rb as Rect2).end.x)
						var gz := maxf((rb as Rect2).position.y - (ra as Rect2).end.y,
								(ra as Rect2).position.y - (rb as Rect2).end.y)
						# only interesting when they overlap on the OTHER axis
						# (i.e. actually face each other across a wall)
						var face_x := gx > 0.0 and gz < 0.0 and gx < 1.5
						var face_z := gz > 0.0 and gx < 0.0 and gz < 1.5
						if face_x:
							print("GAP      %-14s | %-14s  %.2f m along x" % [names[i], names[j], gx])
						elif face_z:
							print("GAP      %-14s | %-14s  %.2f m along z" % [names[i], names[j], gz])
	print("\n(SEAM margin is 0.25 - overlaps well past that double-claim; gaps ~wall thickness ~0.3 are fine, bigger = void strip)")
