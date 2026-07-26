extends Node

# A persistent looping room ambience - a fan, a buzzing light, the AC.
# Drop it on a node inside a room and point `sound` at an ambient file.
# It loops forever and keeps playing THROUGH dialogue (the box pauses the
# world; a room's hum shouldn't cut out every time a line opens).
#
# Non-positional by default (a wash that fills the room). It only plays
# while its room is the active one, so you don't hear every room's fan at
# once - set `room_path` to the owning Room, or leave empty to always play.

@export_file("*.mp3", "*.wav", "*.ogg") var sound := ""
@export var volume_db := -20.0
## the Room this ambience belongs to; only audible while that room is
## current. Empty = always audible.
@export var room_path: NodePath

const RoomState := preload("res://scripts/game/room.gd")

var _player: AudioStreamPlayer
var _room: Node3D


func _ready() -> void:
	add_to_group("room_ambient")
	if sound == "" or not ResourceLoader.exists(sound):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = _looped(load(sound))
	_player.volume_db = volume_db
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_resolve_room()
	_player.play()


# find the owning Room. Done lazily because room.gd adds itself to the
# "room" group in ITS _ready, which may run after ours.
func _resolve_room() -> void:
	if room_path != NodePath():
		_room = get_node_or_null(room_path)
		if _room != null:
			return
	var n: Node = get_parent()
	while n != null:
		# a Room either carries room.gd's group or is a Node3D with the
		# room script; the group is the reliable signal once it's set
		if n.is_in_group("room"):
			_room = n
			return
		n = n.get_parent()


# the endgame's breath-hold: everything ambient sinks away, leaving only
# voices and the heartbeat. One-way - the confrontation ends the loop.
func hush(seconds := 0.8) -> void:
	if _player == null:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_player, "volume_db", -60.0, seconds)


func _process(_delta: float) -> void:
	if _player == null:
		return
	if _room == null:
		_resolve_room()
	# audible only while our room is the active one (or if we truly have no
	# room to bind to)
	var here: bool = _room == null or RoomState.current == _room
	if here and not _player.playing:
		_player.play()
	elif not here and _player.playing:
		_player.stop()


# make sure the ambience actually loops (imported files may not be flagged)
func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamMP3 and not stream.loop:
		stream = stream.duplicate()
		stream.loop = true
	elif stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis and not stream.loop:
		stream = stream.duplicate()
		stream.loop = true
	return stream
