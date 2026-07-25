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
## shown the FIRST time the code is accepted - what you find inside. Each
## entry is {"speaker","text"}. Leave empty for a plain unlock.
@export var reveal_dialogue: Array = []
## a permanent story flag set when the reveal plays (e.g. the proof you
## found). Empty = none.
@export var reveal_flag := ""
## a PER-LOOP flag set every time you open the cracked lock - drives things
## that must RE-CLOSE each loop (the hidden passage doors reseal on restart;
## you swing the locker aside again each run). Empty = none.
@export var opens_loop_flag := ""
## once this flag is raised, the whole prop VANISHES (and stops being
## interactable) - the captain's locker swings away exposing the passage.
## Checked against BOTH flag pools, so a per-loop flag (opens_loop_flag)
## brings the locker BACK each restart. Empty = never hide.
@export var hide_when_flag := ""

var _revealed := false
var _hidden := false


func _ready() -> void:
	add_to_group("talkable")


func _process(_delta: float) -> void:
	if hide_when_flag == "" or _hidden:
		return
	if Flags.has_flag(hide_when_flag) or Flags.has_loop_flag(hide_when_flag):
		_hidden = true
		visible = false
		if is_in_group("talkable"):
			remove_from_group("talkable")


func interact() -> void:
	if sets_flag != "" and Flags.has_flag(sets_flag):
		# already cracked: opening it again is a per-loop act
		var dlg := get_tree().get_first_node_in_group("dialogue")
		if dlg == null or dlg.visible:
			return
		if opens_loop_flag != "":
			Flags.set_loop_flag(opens_loop_flag)
		# the full reveal plays exactly ONCE per game (reveal_flag remembers
		# across loops); later opens just get the short line
		if not _revealed and not reveal_dialogue.is_empty() \
				and (reveal_flag == "" or not Flags.has_flag(reveal_flag)):
			_revealed = true
			if reveal_flag != "":
				Flags.set_flag(reveal_flag)
			dlg.show_dialogue(reveal_dialogue)
		else:
			dlg.show_dialogue([{"speaker": "KEYPAD", "text": unlocked_text}])
		return
	var ui := get_tree().get_first_node_in_group("keypad_ui")
	if ui != null:
		ui.open(code, sets_flag)
