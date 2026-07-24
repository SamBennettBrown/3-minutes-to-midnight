@tool
extends Node3D

# The CHARACTER RIG - shared by the player, every NPC, and the title
# screen. A retargeted Synty character playing retargeted clips
# (docs/SYNTY_ANIMATION_PIPELINE.md): both sides speak the humanoid
# skeleton, so any clip plays on any character with no runtime
# retargeting.
#
# Responsibilities: model + clips + material, animation playback with
# crossfade, footsteps, overheard barks, and conversation selection.
# Movement/schedules belong to whoever owns the rig (controller, NPC
# script) - never here.

const Flags := preload("res://scripts/game/flags.gd")
const ClipUtils := preload("res://scripts/game/clip_utils.gd")
const Conversation := preload("res://scripts/game/conversation.gd")
const RoomState := preload("res://scripts/game/room.gd")

# --- model ---
@export var model_path := "res://scripts/tools/retarget/police_chars_rt.glb"
# GLB conversion loses Synty's texture hookup; packs share atlas materials
@export var material_path := "res://materials/police_01_a.tres"
## pack character FBXs bundle every character mesh on one rig; name one
## (e.g. "SM_Chr_Detective_Male_01") to show it and hide the rest
@export var visible_mesh := ""
## a SM_Chr_Attach_* scene (hair/beard/glasses) bolted to the Head bone
@export_file("*.fbx", "*.glb") var hair_path := ""
@export var hair_offset := Vector3.ZERO
@export var hair_rotation := Vector3.ZERO
@export var hair_scale := 1.0
## tick to rebuild the editor preview after changing mesh/hair fields
@export var refresh_preview := false:
	set(_v):
		if Engine.is_editor_hint() and is_inside_tree():
			if model != null and is_instance_valid(model):
				model.free()
			_build_model()
## small vertical lift so animated feet don't dip below the floor
@export var foot_offset := 0.0
## solid body so the player can't walk through this character - NPCs
## only (the player's own rig must not collide with its capsule)
@export var blocks_player := false
## NPCs: hide when outside the active room (rooms render isolated)
@export var hide_outside_active_room := false

# --- animation ---
@export var clips := {
	"idle": "res://scripts/tools/retarget/idle_rt.glb",
	"walk": "res://scripts/tools/retarget/walk_rt.glb",
	"run": "res://scripts/tools/retarget/run_rt.glb",
	"foottap": "res://scripts/tools/retarget/foottap_rt.glb",
	"lean": "res://scripts/tools/retarget/lean_rt.glb",
	"guard": "res://scripts/tools/retarget/guard_rt.glb",
	"kick": "res://scripts/tools/retarget/kick_rt.glb",
}
@export var start_clip := "walk"
## crossfade between clips, seconds
@export var blend_time := 0.25
## play clips in place - for characters whose position is driven
## externally (player controller, scheduled NPCs)
@export var strip_root_motion := false

# --- audio ---
@export var footstep_paths: Array[String] = [
	"res://audio/sfx/walk1.wav", "res://audio/sfx/walk2.wav", "res://audio/sfx/walk3.wav",
	"res://audio/sfx/walk4.wav", "res://audio/sfx/walk5.wav", "res://audio/sfx/walk6.wav",
]
@export var footstep_volume_db := -10.0
## seconds between steps while walking; running steps come 40% faster
@export var footstep_interval := 0.5

# --- conversation (see game/conversation.gd for the variant format) ---
@export var dialogue: Array = []
@export var sets_flag := ""
@export var dialogue_variants: Array = []

var anim_player: AnimationPlayer
var model: Node3D
var current_clip := ""
var prompt_height := 2.05

var _dlg: Node
var _steps: Array = []
var _step_player: AudioStreamPlayer3D
var _step_timer := 0.1
var _step_i := 0
var _bark_label: Label3D
var _bark_timer := 0.0
var _seen_once := {}


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_model()
		return
	if not _build_model():
		return
	_build_clips()
	_build_collision()
	_build_footsteps()
	play(start_clip)
	# the model spawns in T-pose and only takes its first animated pose
	# a couple of frames later - hide it until then to avoid a flash
	model.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(model):
		model.visible = true


func _build_model() -> bool:
	if not ResourceLoader.exists(model_path):
		push_error("[rig] missing model: " + model_path)
		return false
	model = load(model_path).instantiate()
	add_child(model)
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_error("[rig] no skeleton in " + model_path)
		return false
	# normalize scale: GLB exports can arrive 100x; aim hips at ~0.95m
	var h := ClipUtils.hips_height(skels[0])
	if h > 0.05:
		model.scale = model.scale * (0.95 / h)
	model.position.y += foot_offset
	if visible_mesh != "":
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			mi.visible = visible_mesh in mi.name
	if material_path != "" and ResourceLoader.exists(material_path):
		var mat: Material = load(material_path)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mat
	_attach_hair(skels[0])
	return true


# Synty hair/beard/hat attachments ride the Head bone. Pick the piece
# per character with hair_path; nudge fit with the offset/rotation.
func _attach_hair(skeleton: Skeleton3D) -> void:
	if hair_path == "" or not ResourceLoader.exists(hair_path):
		return
	var head := skeleton.find_bone("Head")
	if head < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skeleton.add_child(att)
	var hair: Node3D = load(hair_path).instantiate()
	att.add_child(hair)
	hair.position = hair_offset
	hair.rotation_degrees = hair_rotation
	hair.scale = Vector3.ONE * hair_scale
	# the hair FBX keeps its OWN imported atlas material - overriding it
	# with the body character material greens the head (hair UVs map to a
	# different atlas region than the body)


func _build_clips() -> void:
	anim_player = AnimationPlayer.new()
	model.add_child(anim_player)
	var lib := AnimationLibrary.new()
	for clip_name in clips:
		var a := _load_clip(clips[clip_name])
		if a != null:
			lib.add_animation(clip_name, a)
	anim_player.add_animation_library("clips", lib)


func _load_clip(path: String) -> Animation:
	if not ResourceLoader.exists(path):
		push_warning("[rig] missing clip: " + path)
		return null
	var scene: Node = load(path).instantiate()
	var p: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	if p == null or p.get_animation_list().is_empty():
		scene.free()
		push_warning("[rig] no animation in " + path)
		return null
	var a: Animation = p.get_animation(p.get_animation_list()[0]).duplicate()
	scene.free()
	ClipUtils.prep_clip(a)
	if strip_root_motion:
		ClipUtils.strip_root_motion(a)
	return a


func _build_collision() -> void:
	if not blocks_player:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	add_child(body)


func _build_footsteps() -> void:
	_step_player = AudioStreamPlayer3D.new()
	_step_player.volume_db = footstep_volume_db
	_step_player.max_distance = 14.0
	add_child(_step_player)
	for p in footstep_paths:
		if ResourceLoader.exists(p):
			_steps.append(load(p))


# --- playback ---

func play(clip_name: String) -> void:
	if clip_name == current_clip:
		return
	if anim_player != null and anim_player.has_animation("clips/" + clip_name):
		current_clip = clip_name
		anim_player.play("clips/" + clip_name, blend_time)


# --- conversation ---

func get_conversation() -> Dictionary:
	# picked atomically: lines + flag from the same variant
	var idx := Conversation.pick(dialogue_variants, _seen_once, _clock_time())
	if idx < 0:
		return {"lines": dialogue, "sets_flag": sets_flag}
	var v: Dictionary = dialogue_variants[idx]
	if bool(v.get("once", false)):
		_seen_once[idx] = true
	return {"lines": v.get("lines", []), "sets_flag": String(v.get("sets_flag", ""))}


func _clock_time() -> float:
	var clock := get_tree().get_first_node_in_group("loop_clock")
	return clock.time if clock != null else 0.0


# --- barks (overheard speech) ---

func bark(text: String, duration := 3.0) -> void:
	# floating text above the head, world keeps moving - the bottom
	# dialogue box is only for conversations WITH the player
	if _bark_label == null:
		_bark_label = Label3D.new()
		_bark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bark_label.no_depth_test = true
		_bark_label.pixel_size = 0.005
		_bark_label.font_size = 40
		_bark_label.outline_size = 10
		_bark_label.width = 520.0
		_bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bark_label.modulate = Color(0.95, 0.95, 0.93)
		_bark_label.position = Vector3(0, prompt_height + 0.4, 0)
		add_child(_bark_label)
	_bark_label.text = text
	_bark_label.visible = true
	_bark_timer = duration


# --- per-frame: pause behavior, bark expiry, footsteps ---

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if hide_outside_active_room and model != null:
		# is_instance_valid: the static survives scene reloads pointing at
		# a freed room until the new start room re-activates
		var room := RoomState.current
		# visible when the ACTIVE room sees us, OR when the room we're
		# standing in is being rendered for another reason - e.g. the
		# observation window peek reveals interrogation (room.visible=true)
		# while the active room is still Observation
		model.visible = not is_instance_valid(room) \
				or room.sees_point(global_position, 1.2) \
				or _standing_room_visible()

	if _dlg == null:
		_dlg = get_tree().get_first_node_in_group("dialogue")
		if _dlg != null:
			# conversations look dead if the speakers freeze mid-stride
			_dlg.opened.connect(func() -> void: play("idle"))

	# dialogue = alive (speakers keep breathing), any other pause
	# (menu, journal) = frozen solid; flipping the AnimationPlayer's own
	# process mode lets the engine enforce it
	if anim_player != null:
		var dlg_open: bool = _dlg != null and _dlg.visible
		anim_player.process_mode = Node.PROCESS_MODE_ALWAYS if dlg_open \
				else Node.PROCESS_MODE_PAUSABLE

	if get_tree().paused:
		return

	if _bark_timer > 0.0:
		_bark_timer -= _delta
		if _bark_timer <= 0.0 and _bark_label != null:
			_bark_label.visible = false

	_step_footsteps(_delta)


# is the room this character physically stands in currently rendering?
# lets a peek (which flips a non-active room's .visible on) reveal the
# NPCs inside it, even though RoomState.current is elsewhere
func _standing_room_visible() -> bool:
	for r in get_tree().get_nodes_in_group("room"):
		if r.visible and r.has_method("contains_point") \
				and r.contains_point(global_position, 0.5):
			return true
	return false


func _step_footsteps(delta: float) -> void:
	if _steps.is_empty():
		return
	if current_clip == "walk" or current_clip == "run":
		_step_timer -= delta * (1.4 if current_clip == "run" else 1.0)
		if _step_timer <= 0.0:
			_step_timer = footstep_interval
			_step_player.stream = _steps[_step_i % _steps.size()]
			_step_i += 1
			_step_player.play()
	else:
		_step_timer = 0.15
