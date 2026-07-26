extends Node

# The score. A 3-minute track authored to the 3-minute night, kept in
# lockstep with the loop clock (both pause together, so 0:00 in the music
# is 0:00 on the wall).
#
# Dialogue: the main track FREEZES at its exact position and the _pause
# variant takes over underneath, pitched down (tape dragged slow). When
# the box closes, the variant stops and the main track resumes from the
# very frame it left. Menus/journal just pause the music with the world.
#
# Spawned by loop_clock at runtime - no scene wiring needed.

const Flags := preload("res://scripts/game/flags.gd")

const TRACK := "res://audio/bg/bg music.mp3"
const TRACK_PAUSE := "res://audio/bg/bg music_pause.mp3"
const VOLUME_DB := -12.0
const PAUSE_VOLUME_DB := -16.0
## "slightly lower pitch, like .2"
const PAUSE_PITCH := 0.8

var _main: AudioStreamPlayer
var _under: AudioStreamPlayer
var _clock: Node
var _dlg: Node
var _in_dialogue := false

# exactly ONE score may exist - a restart mid-dialogue once left two beds
# running over each other
static var _live: Node


func _ready() -> void:
	if is_instance_valid(_live) and _live != self:
		_live.queue_free()
	_live = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(TRACK):
		set_process(false)
		return
	_main = _make_player(TRACK, VOLUME_DB)
	if ResourceLoader.exists(TRACK_PAUSE):
		_under = _make_player(TRACK_PAUSE, PAUSE_VOLUME_DB)
		_under.pitch_scale = PAUSE_PITCH
	_clock = get_tree().get_first_node_in_group("loop_clock")


func _make_player(path: String, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStream = load(path)
	# always loop - a short variant must hold under a long conversation,
	# and the main track wraps if a loop ever runs past its length
	if s is AudioStreamMP3 and not s.loop:
		s = s.duplicate()
		s.loop = true
	p.stream = s
	p.volume_db = vol
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _process(_delta: float) -> void:
	if _main == null:
		return
	if _dlg == null:
		_dlg = get_tree().get_first_node_in_group("dialogue")
		if _dlg != null:
			_dlg.opened.connect(_on_dialogue_open)
			_dlg.closed.connect(_on_dialogue_close)
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	# silence until the intro hands over; fade out when the endgame freezes
	# the night (the world holds its breath - the score does too)
	if not Flags.has_flag("bound_promise"):
		return
	if _clock.frozen:
		_main.volume_db = move_toward(_main.volume_db, -60.0, _delta * 24.0)
		if _under != null and _under.playing:
			_under.stop()
		return
	if not _main.playing:
		_main.play(fmod(float(_clock.time), _track_len()))
	if _in_dialogue:
		# self-heal: if the dialogue is actually gone (scene churn, restart)
		# the slow variant must not linger under the fresh main track
		if _dlg == null or not is_instance_valid(_dlg) or not _dlg.visible:
			_on_dialogue_close()
		return
	if _under != null and _under.playing:
		# never both at once outside a dialogue
		_under.stop()
	# outside dialogue: the music pauses whenever the world does (menus,
	# journal, keypad), and re-syncs to the clock on the way back in
	var want_paused: bool = get_tree().paused
	if _main.stream_paused != want_paused:
		_main.stream_paused = want_paused
		if not want_paused:
			var target := fmod(float(_clock.time), _track_len())
			if absf(_main.get_playback_position() - target) > 0.4:
				_main.seek(target)


func _track_len() -> float:
	return maxf(_main.stream.get_length(), 1.0)


func _on_dialogue_open() -> void:
	if _main == null or not _main.playing:
		return
	_in_dialogue = true
	# freeze the score mid-note; the dragged-slow variant carries the room
	_main.stream_paused = true
	if _under != null:
		_under.play(fmod(_main.get_playback_position(), maxf(_under.stream.get_length(), 1.0)))


func _on_dialogue_close() -> void:
	_in_dialogue = false
	if _under != null and _under.playing:
		_under.stop()
	if _main != null:
		# resume from the exact frame it froze on
		_main.stream_paused = false
