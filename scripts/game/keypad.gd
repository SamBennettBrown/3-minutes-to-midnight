extends Node3D

const Tuning := preload("res://scripts/game/tuning.gd")

# A keypad lock: interact to open the code-entry UI. The code lives on
# a note somewhere in the world - knowledge, not a key item. The lock
# itself RESETS completely: you punch the code in every single time -
# what persists across loops is only what you KNOW (sets_flag) and what
# the story has revealed (reveal_flag).

const Flags := preload("res://scripts/game/flags.gd")
const Sfx := preload("res://scripts/game/sfx.gd")

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
## how many reveal lines play BEFORE the door actually opens - the beat
## lands mid-dialogue ("...that's not what I expected" -> the locker swings
## aside -> the realisation continues over the open passage)
@export var reveal_open_after := 2

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
		# the auto-collider boxed this prop at startup; hiding the mesh
		# leaves that invisible box behind and it walls off the doorway -
		# kill the collision along with the visual
		for cs in find_children("*", "CollisionShape3D", true, false):
			cs.disabled = true


func interact() -> void:
	# the lock never remembers - every open means punching the code in again
	var ui := get_tree().get_first_node_in_group("keypad_ui")
	if ui != null:
		ui.open(code, sets_flag, _on_code_accepted)


func _on_code_accepted() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue")
	var fresh: bool = not _revealed and not reveal_dialogue.is_empty() \
			and (reveal_flag == "" or not Flags.has_flag(reveal_flag)) \
			and dlg != null and not dlg.visible
	if not fresh:
		# repeat opens: the passage just swings aside, no ceremony
		_open_passage()
		return
	_revealed = true
	if reveal_flag != "":
		Flags.set_flag(reveal_flag)
	# the beat: expectation first ("let's have that gun... that's not what I
	# expected"), THEN the locker swings off the wall, THEN the realisation
	var cut := clampi(reveal_open_after, 0, reveal_dialogue.size())
	if cut > 0:
		dlg.show_dialogue(reveal_dialogue.slice(0, cut))
		await dlg.closed
		if not is_inside_tree():
			return
	_open_passage()
	if cut < reveal_dialogue.size():
		dlg.show_dialogue(reveal_dialogue.slice(cut))


func _open_passage() -> void:
	if opens_loop_flag == "":
		return
	Flags.set_loop_flag(opens_loop_flag)
	# the locker grinding off the wall
	Sfx.play_at(self, "res://audio/sfx/door_close.mp3", -8.0)
