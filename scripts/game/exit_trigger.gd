extends Area3D

# The precinct's front door. You never leave through it - the promise in
# your pocket won't let you until the witness makes it through the night.
# Reaching the door earns a line and turns you back; an invisible wall
# fills the gap so you can't walk out into the void. The story moves at the
# reception desk and deeper in the station, never out this door.

var _cooldown := 0.0
var _wall: StaticBody3D


func _ready() -> void:
	body_entered.connect(_on_enter)
	_build_wall()


# a slim solid barrier filling the exit gap, sized to this trigger
func _build_wall() -> void:
	_wall = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.4)
	cs.shape = box
	_wall.add_child(cs)
	add_child(_wall)
	# sit it at the doorway plane, just past the trigger, spanning the gap
	_wall.position = Vector3(0, 0.2, 0.4)


func _on_enter(body: Node3D) -> void:
	if _cooldown > 0.0 or not body.is_in_group("player"):
		return
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	# small cooldown so brushing the trigger doesn't re-fire every frame
	_cooldown = 4.0
	dlg.show_dialogue([{"speaker": "DETECTIVE",
			"text": "The trinket burns cold in my pocket. I can't leave. Not until he makes it through this night."}])


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
