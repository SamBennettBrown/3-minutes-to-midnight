extends Node

# The score, kept simple for ship: "bg music full" plays under the whole
# night, synced to the loop clock. Whenever the world pauses (dialogue,
# menu, journal, keypad) it freezes at its exact position and resumes
# from the same frame on unpause. Ambience carries the pauses.
#
# Silent exceptions: the endgame freeze (breath-hold) and the lose screen
# (gunshot + rewind own the soundscape).
#
# Spawned by loop_clock at runtime - no scene wiring needed.

const Flags := preload("res://scripts/game/flags.gd")

const TRACK := "res://audio/bg/bg music full.mp3"
const VOLUME_DB := -12.0

var _main: AudioStreamPlayer
# the pause soundscape: the AC hum swells up and the trinket tick-tocks
# while the world is frozen
var _pause_ac: AudioStreamPlayer
var _tick_t := 0.0
var _tock := false
var _clock: Node
var _lose: Node

# exactly ONE score may exist across restarts
static var _live: Node


func _ready() -> void:
	if is_instance_valid(_live) and _live != self:
		_live.queue_free()
	_live = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(TRACK):
		set_process(false)
		return
	var stream: AudioStream = load(TRACK)
	if stream is AudioStreamMP3 and not stream.loop:
		stream = stream.duplicate()
		stream.loop = true
	_main = AudioStreamPlayer.new()
	_main.stream = stream
	_main.volume_db = VOLUME_DB
	_main.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_main)
	if ResourceLoader.exists("res://audio/ambient/air_conditioner.mp3"):
		var ac: AudioStream = load("res://audio/ambient/air_conditioner.mp3")
		if ac is AudioStreamMP3 and not ac.loop:
			ac = ac.duplicate()
			ac.loop = true
		_pause_ac = AudioStreamPlayer.new()
		_pause_ac.stream = ac
		_pause_ac.volume_db = -60.0
		_pause_ac.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_pause_ac)
		_pause_ac.play()
	_clock = get_tree().get_first_node_in_group("loop_clock")


func _process(_delta: float) -> void:
	if _main == null:
		return
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("loop_clock")
		return
	if _lose == null:
		_lose = get_tree().get_first_node_in_group("lose_screen")
	# silence until the intro hands over
	if not Flags.has_flag("bound_promise"):
		return
	# the endgame freeze and the death/rewind own the soundscape
	if _clock.frozen or (_lose != null and _lose.is_active()):
		_main.volume_db = move_toward(_main.volume_db, -60.0, _delta * 24.0)
		return
	if not _main.playing:
		_main.play(fmod(float(_clock.time), maxf(_main.stream.get_length(), 1.0)))
	# any pause freezes the score in place; unpause resumes the same frame
	# but SWELLS back in instead of slamming to full volume
	var paused: bool = get_tree().paused
	if _main.stream_paused and not paused:
		_main.volume_db = -26.0
	_main.stream_paused = paused
	if not paused:
		_main.volume_db = move_toward(_main.volume_db, VOLUME_DB, _delta * 30.0)
	# the frozen world: AC hum swells up and the trinket keeps time.
	# Quieter under DIALOGUE so it sits beneath the voices; fuller on the
	# pause menu where it carries the room alone.
	if _pause_ac != null:
		var ac_target := -60.0
		if paused:
			var dlg := get_tree().get_first_node_in_group("dialogue")
			ac_target = -26.0 if (dlg != null and dlg.visible) else -16.0
		_pause_ac.volume_db = move_toward(_pause_ac.volume_db, ac_target, _delta * 40.0)
	if paused:
		_tick_t -= _delta
		if _tick_t <= 0.0:
			_tick_t = 1.0
			_tock = not _tock
			var tick := AudioStreamPlayer.new()
			tick.stream = load("res://audio/ambient/tock.mp3" if _tock \
					else "res://audio/ambient/tick.mp3")
			tick.volume_db = -14.0
			tick.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(tick)
			tick.play()
			tick.finished.connect(tick.queue_free)
	else:
		_tick_t = 0.0