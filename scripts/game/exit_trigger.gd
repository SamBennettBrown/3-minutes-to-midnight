extends Area3D

# The precinct's front door. You never actually leave through it - the
# night won't let you. On loop 0 you don't even know that yet; on every
# loop after, the promise in your pocket is why. Either way, reaching the
# door just earns a line and turns you back. The story moves at the
# reception desk, not out this door.

const Flags := preload("res://scripts/game/flags.gd")

var _cooldown := 0.0


func _ready() -> void:
	body_entered.connect(_on_enter)


func _on_enter(body: Node3D) -> void:
	if _cooldown > 0.0 or not body.is_in_group("player"):
		return
	var dlg := get_tree().get_first_node_in_group("dialogue")
	if dlg == null or dlg.visible:
		return
	# small cooldown so brushing the trigger doesn't re-fire every frame
	_cooldown = 4.0
	# LOOP 1 is the reveal: you think you're going home, and the door
	# throws you back to 11:57. That "bam" is how you learn you're looping.
	if Flags.has_flag("intro_done") and Flags.loops == 1:
		dlg.show_dialogue([{"speaker": "DETECTIVE",
				"text": "Finally. Home. Just one more step and-"}])
		await dlg.closed
		if not is_inside_tree():
			return
		var lose := get_tree().get_first_node_in_group("lose_screen")
		if lose != null:
			lose.play_lose()
		return
	# loop 0 (haven't learned yet) and loop 2+ (know better): the door just
	# turns you back - the promise won't let you leave
	if Flags.has_flag("intro_done"):
		dlg.show_dialogue([{"speaker": "DETECTIVE",
				"text": "The trinket burns cold in my pocket. I can't leave. Not until he makes it through this night."}])
	else:
		dlg.show_dialogue([{"speaker": "DETECTIVE",
				"text": "Home's the other side of that door. But something says the night isn't done with me yet. Not before I've talked to the desk."}])


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
