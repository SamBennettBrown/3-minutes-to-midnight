# One home for numbers that appear in more than one script. Preload:
#   const Tuning := preload("res://scripts/game/tuning.gd")

## seconds per loop - the title is a promise: three minutes to midnight
const LOOP_LENGTH := 180.0

## m/s the walk/run clips were authored at - animation speed_scale is
## derived from these so feet grip the floor everywhere
const WALK_PACE := 1.6
const RUN_PACE := 3.4

## how close the player must be to talk/examine - the E prompt and the
## actual interact check must always agree
const INTERACT_RANGE := 2.0

## the holding-cells keypad code (written on the maintenance slip -
## keep the slip's dialogue text in sync if this changes)
const CELLS_CODE := "4471"
