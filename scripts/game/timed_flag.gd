extends Node

# Sets a flag at a fixed loop time - deterministic, player-independent.
# The building block for scheduled world state: a door that unlocks when
# the guards leave, a room that seals at a moment, an alarm that arms.
#
# Reads the loop clock's `time` (elapsed seconds), so it fires at the
# same instant every loop. `per_loop` off = the knowledge sticks across
# loops; on = it re-arms each restart (cleared with the other loop flags).

const Flags := preload("res://scripts/game/flags.gd")

## the flag to raise
@export var flag := ""
## loop time (elapsed seconds) at which to raise it
@export var at := 0.0
## loop flag (re-arms every restart) vs permanent knowledge
@export var per_loop := true

var _fired := false
var _clock: Node


func _process(_delta: float) -> void:
	if _fired or flag == "":
		return
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	if _clock.time >= at:
		_fired = true
		if per_loop:
			Flags.set_loop_flag(flag)
		else:
			Flags.set_flag(flag)
