extends Node3D

const Tuning := preload("res://scripts/game/tuning.gd")

# A keypad lock: interact to open the code-entry UI. The code lives on
# a note somewhere in the world - knowledge, not a key item. Once the
# flag is set, the keypad stays unlocked every loop (Deathloop clause).

const Flags := preload("res://scripts/game/flags.gd")

@export var code := Tuning.CELLS_CODE
@export var sets_flag := "cells_unlocked"
@export var unlocked_text := "The lock is already open. It remembers, same as you."
@export var prompt_height := 0.5


func _ready() -> void:
	add_to_group("talkable")


func interact() -> void:
	if sets_flag != "" and Flags.has_flag(sets_flag):
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg != null:
			dlg.show_dialogue([{"speaker": "KEYPAD", "text": unlocked_text}])
		return
	var ui := get_tree().get_first_node_in_group("keypad_ui")
	if ui != null:
		ui.open(code, sets_flag)
