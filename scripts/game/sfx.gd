# One-shot sound helpers. Spawns a player, plays, frees itself.
#
#   const Sfx := preload("res://scripts/game/sfx.gd")
#   Sfx.play(self, "res://audio/sfx/door_close.mp3", -14.0)
#   Sfx.play_at(self, "res://audio/sfx/bump.mp3", -10.0)  # positional
#
# For looping/persistent audio, own an AudioStreamPlayer instead.


static func play(parent: Node, path: String, volume_db := 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var a := AudioStreamPlayer.new()
	a.stream = _one_shot(load(path))
	a.volume_db = volume_db
	# keep sounding even while a dialogue box has the world paused - a
	# gunshot or alarm shouldn't cut off the instant a line opens
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


static func play_at(parent: Node, path: String, volume_db := 0.0, max_seconds := 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = _one_shot(load(path))
	a.volume_db = volume_db
	# audible in-room and a little beyond, then GONE - and no distance
	# lowpass (it reads as the sound sagging in pitch)
	a.max_distance = 14.0
	a.attenuation_filter_cutoff_hz = 20500
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
	if max_seconds > 0.0:
		# long recordings (a phone that rings for a minute) get cut short.
		# the Timer is a CHILD of the sound player: if the sound finishes
		# and frees first, the timer dies with it - nothing dangles
		var t := Timer.new()
		t.wait_time = max_seconds
		t.one_shot = true
		t.autostart = true
		t.timeout.connect(a.queue_free)
		a.add_child(t)


# import-looped files (ambience) would play forever and never free -
# a one-shot is a one-shot, so strip the loop off a private copy
static func _one_shot(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamMP3 and stream.loop:
		stream = stream.duplicate()
		stream.loop = false
	elif stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis and stream.loop:
		stream = stream.duplicate()
		stream.loop = false
	return stream
