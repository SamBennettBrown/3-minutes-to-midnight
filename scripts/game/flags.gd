# Story flags: what the detective has learned. Statics live on the
# script, not the scene, so flags SURVIVE loop restarts and only reset
# when the game closes - the whole point of a time loop.
#
# Usage (any script):
#   const Flags := preload("res://scripts/game/flags.gd")
#   Flags.set_flag("read_case_file")
#   if Flags.has_flag("read_case_file"): ...
#
# No disk saves yet (a jam session doesn't need them). When we want
# them, save()/load() here wrap _flags in a ConfigFile - nothing else
# in the game has to change.

static var _flags := {}

# how many loops have started this session; the loop clock bumps it on
# every scene load, so the first playable loop is 1. Some beats escalate
# with the count (the rookie closes in faster each loop).
static var loops := 0

# total seconds of live play this session (the loop clock accumulates it;
# survives restarts) - shown in the win credits for fun
static var playtime := 0.0


# callables invoked with (flag_name) the first time a flag is set;
# stale callables from reloaded scenes are pruned automatically
static var _listeners: Array[Callable] = []


static func subscribe(cb: Callable) -> void:
	for i in range(_listeners.size() - 1, -1, -1):
		if not _listeners[i].is_valid():
			_listeners.remove_at(i)
	_listeners.append(cb)


static func set_flag(flag_name: String) -> void:
	if _flags.has(flag_name):
		return
	_flags[flag_name] = true
	for i in range(_listeners.size() - 1, -1, -1):
		if _listeners[i].is_valid():
			_listeners[i].call(flag_name)
		else:
			_listeners.remove_at(i)


static func has_flag(flag_name: String) -> bool:
	return _flags.has(flag_name)


# --- per-loop state: what you HOLD, not what you know ---
# Objects reset with the world: a keycard taken THIS loop, an item in
# your pocket. Cleared by the loop clock when a new loop starts, so
# every pickup has to be re-stolen on the final run - that's the game.

static var _loop_flags := {}


static func set_loop_flag(flag_name: String) -> void:
	_loop_flags[flag_name] = true


static func has_loop_flag(flag_name: String) -> bool:
	return _loop_flags.has(flag_name)


# spend a single per-loop holding (e.g. the chips are consumed making the
# weight swap) without wiping the rest
static func clear_loop_flag(flag_name: String) -> void:
	_loop_flags.erase(flag_name)


static func clear_loop_flags() -> void:
	_loop_flags.clear()


# full fresh-start (the win resets to the title, "New Game"): knowledge,
# loop count, and the session stopwatch
static func clear() -> void:
	_flags.clear()
	_loop_flags.clear()
	loops = 0
	playtime = 0.0
