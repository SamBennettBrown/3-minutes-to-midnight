extends "res://scripts/game/auto_collider.gd"

# Library compactus: the direct SM_Prop_Shelf_* children become a bank
# of rolling shelves on one rail with a single open aisle. Interacting
# with the crank (this node) rolls the aisle one slot along - things
# deep in the stacks are only reachable when their aisle is open,
# because the shelf colliders physically block you otherwise.
# Also inherits auto-collision for everything underneath.

const Sfx := preload("res://scripts/game/sfx.gd")

## gap between packed shelves when an aisle opens here
@export var aisle_width := 1.4
## distance between packed shelf centers
@export var shelf_pitch := 1.1
@export var slide_time := 0.9
## which aisle starts open (0 = before the first shelf)
@export var start_gap := 0
@export var prompt_height := 1.2

var _shelves: Array = []
var _rail_x := 0.0
var _gap := 0


func _ready() -> void:
	super._ready()
	add_to_group("talkable")
	for c in get_children():
		if c.name.begins_with("SM_Prop_Shelf") and c is Node3D:
			_shelves.append(c)
	_shelves.sort_custom(func(a, b): return a.position.x < b.position.x)
	if _shelves.is_empty():
		return
	_rail_x = _shelves[0].position.x
	_gap = clampi(start_gap, 0, _shelves.size())
	_pack(0.0)


func interact() -> void:
	_gap = (_gap + 1) % (_shelves.size() + 1)
	Sfx.play_at(self, "res://audio/sfx/door_close.mp3", -18.0)
	_pack(slide_time)


func _pack(dur: float) -> void:
	for k in _shelves.size():
		var x := _rail_x + float(k) * shelf_pitch
		if k >= _gap:
			x += aisle_width
		if dur <= 0.0:
			_shelves[k].position.x = x
		else:
			var tw := create_tween()
			tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_shelves[k], "position:x", x, dur)
