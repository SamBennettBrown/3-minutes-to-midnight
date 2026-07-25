extends StaticBody3D

# A barrier that opens when a flag is set: locked doors, card readers,
# blocked passages. `per_loop` on = checks what you're HOLDING this loop
# (re-locks each restart); off = knowledge opens it forever.
# `let_out` = one-way, always passable from the +Z side.
# `locked_line` = shown once per loop when you bump the closed gate.

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

@export var open_flag := ""
@export var per_loop := false
## DEBUG: force this gate permanently open (for testing rooms behind a
## lock you haven't wired the key for yet). Leave off for real play.
@export var force_open := false
## a LOOP flag that slams the gate shut regardless of the key (lockdown)
@export var closed_by_loop_flag := ""
@export var let_out := false
@export var locked_speaker := "DOOR"
@export var locked_line := ""
## played once the moment the gate actually OPENS (card accepted, code
## entered) - a reader beep. Empty = silent.
@export_file("*.wav", "*.ogg", "*.mp3") var open_sound := ""
@export var open_volume_db := -6.0

var _said := false
var _shapes: Array = []
var _open := false  # cached; the mesh/collision only update on a change
var _ready_done := false


func _ready() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			_shapes.append(c)
	_apply(_is_flagged_open())
	_ready_done = true


func _is_flagged_open() -> bool:
	if force_open:
		return true
	if closed_by_loop_flag != "" and Flags.has_loop_flag(closed_by_loop_flag):
		return false
	if open_flag == "":
		return false
	return Flags.has_loop_flag(open_flag) if per_loop else Flags.has_flag(open_flag)


func _process(_delta: float) -> void:
	var open := _is_flagged_open()
	# one-way door: also open when the player is on the outbound (+Z) side
	if not open and let_out:
		var p: Node3D = get_tree().get_first_node_in_group("player")
		if p != null and (p.global_position - global_position) \
				.dot(global_transform.basis.z) < 0.0:
			open = true
	if open != _open:
		_apply(open)
	if _open or locked_line == "" or _said:
		return
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	# HORIZONTAL distance - gate nodes are mounted ~1.5m up, so a full 3D
	# distance check could never drop under the old 1.4m threshold and the
	# locked line never fired at all
	var flat := global_position - p.global_position
	flat.y = 0.0
	if flat.length() < 1.8:
		_said = true
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null and not dlg.visible:
			dlg.show_dialogue([{"speaker": locked_speaker, "text": locked_line}])


func _apply(open: bool) -> void:
	# a reader beep on a real open transition - but ONLY if the player is
	# close enough to hear it. The gate opens the INSTANT its flag is set
	# (e.g. palming the keycard at the front desk, rooms away), and a
	# cross-building beep at pickup time reads as a glitch.
	if open and not _open and _ready_done and open_sound != "":
		var p: Node3D = get_tree().get_first_node_in_group("player")
		if p != null and global_position.distance_to(p.global_position) < 7.0:
			Sfx.play_at(self, open_sound, open_volume_db)
	_open = open
	visible = not open
	for c in _shapes:
		c.disabled = open
