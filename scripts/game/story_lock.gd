# Shared "is this thing unlocked yet?" check. Interactables that should
# only come alive once the story reaches a point (past the tutorial, after
# a clue is learned, etc.) gate their prompt/visibility through this so the
# rule lives in one place.
#
#   const StoryLock := preload("res://scripts/game/story_lock.gd")
#   if StoryLock.is_unlocked(unlock_flag): ...   # in _process
#
# `unlock_flag` conventions:
#   ""               -> always unlocked (no gate)
#   "bound_promise"  -> unlocked once the opening monologue hands over control
#   any other flag   -> unlocked once that permanent flag is set
#
# Everything here is static and side-effect free - safe to call every frame.

const Flags := preload("res://scripts/game/flags.gd")


static func is_unlocked(unlock_flag: String) -> bool:
	if unlock_flag == "":
		return true
	return Flags.has_flag(unlock_flag)
