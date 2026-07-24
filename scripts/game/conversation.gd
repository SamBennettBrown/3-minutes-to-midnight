# Conversation variant picker. Static, stateless - the caller owns the
# "seen this loop" dictionary (it must reset with the scene).
#
# Variants: [{flag, not_flag, after, before, once, lines, sets_flag}]
#   flag / not_flag - story flag must be set / unset
#   after / before  - loop-clock time window in seconds
#   once            - only once per loop (caller marks `seen`)
# The LAST matching entry wins; author a repeatable quip first so
# `once` entries have something to fall through to.

const Flags := preload("res://scripts/game/flags.gd")


static func pick(variants: Array, seen: Dictionary, time: float) -> int:
	var best := -1
	for i in variants.size():
		var v: Dictionary = variants[i]
		if bool(v.get("once", false)) and seen.has(i):
			continue
		var f := String(v.get("flag", ""))
		if f != "" and not Flags.has_flag(f):
			continue
		var nf := String(v.get("not_flag", ""))
		if nf != "" and Flags.has_flag(nf):
			continue
		if time < float(v.get("after", 0.0)) or time > float(v.get("before", 1e9)):
			continue
		best = i
	return best
