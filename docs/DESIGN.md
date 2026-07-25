# THREE MINUTES TO MIDNIGHT — Design Record

*Game jam, theme: **Count Down**. A time-loop noir mystery in a police
station. Fixed cameras, hard cuts, black & white. Loop = **3:00**
(`Tuning.LOOP_LENGTH`) — the title is a promise.*

## Premise (LOCKED 2026-07-24 — Loop 0/1 SCRAPPED)

A time-loop noir. The witness the detective saved pressed a family
heirloom into his hand out of gratitude — it's the source of the loop.
The witness is murdered in the cells before midnight; the heirloom won't
let the night end until the detective solves it and saves him. When the
clock strikes 12:00 it snaps back to 11:57. Three minutes, over and over.

**The truth (what the player uncovers):**
- HOW: after the witness is walked to the cells and everyone leaves, the
  CAPTAIN goes to the locker room, takes the HIDDEN PASSAGE (locker →
  tunnel → cells) and shoots him from the cell-side, then slips back. The
  cell looks sealed with only an unarmed prisoner inside — the killer
  comes and goes through the wall. The passage IS the murder method.
- WHY (LOCKED 2026-07-25): the criminal the witness is testifying against
  is the CAPTAIN'S BROTHER. The testimony would send his brother to prison,
  so the captain kills the witness to bury the case. Family, not money.
- THE CHAIN (two locations, one carried item):
  1. EVIDENCE ROOM → weight-swap → grab the PACKAGE. The package IS the
     brother-proof: a family photo of the captain with his brother, next to
     the case-file MUGSHOT of the criminal the witness is testifying against
     — the same face. This is the physical evidence you CARRY
     (`have_evidence_package`, per-loop). It also tells you WHY, and makes you
	 want to search the captain's LOCKER for the gun.
  2. LOCKER (0806) → you go looking for the weapon, but instead you find the
	 HIDDEN DOORWAY behind it — the murder method. Cracking it sets
	 `captain_is_guilty` (knowledge) and opens the passage + unlocks the
	 endgame intercept.
- PHYSICAL-EVIDENCE WIN: the win requires you to be HOLDING the package this
  run — grab it from evidence → stage the rookie → be in the locker room
  2:45-3:00 with the package in hand. `captain_is_guilty` (from the locker)
  unlocks the intercept; the package (carried) is what lets you nail him.
- EARLY SEED: an officer's medals bark ("I sneak into the captain's office to
  look at his medals… hope I'm that decorated one day") draws attention to
  the captain before the evidence names him.

### NO INTRO CUTSCENE, NO SCRIPTED LOOPS 0/1
The whole special-cased tutorial (stand-ins, desk check-in, time-skip,
scripted gunshot, rooms_sealed, active_in_intro, know_loop gating, generic
intro lines) is REMOVED. Every loop is the same core loop from frame one.

**Opening (once, on a black screen or a slow camera drift over the map):**
a gunshot, then the monologue —
> *That sound again. Three minutes to midnight. My shift's almost over,
> but no matter what I do it's always the same.*
> *I got my witness his justice and the protection he needed. He was so
> thankful he gave me this — a family heirloom. Then it happens. He's
> killed in the cell block, and there's no one in there but a prisoner
> with no gun. He's walked in, everyone leaves - and a minute later he's
> dead. When the clock strikes twelve, it's back to 11:57.*
> *I could throw this thing in the trash and be done. But this is the
> job. So — here we go again.*

Then control, the 3:00 countdown, and the first journal entry:
**THE IMPOSSIBLE DEATH** — *"A man died alone in a sealed cell, no weapon.
Impossible. My only lead: the cell block. Start there."*

### The breadcrumb trail (self-guided, no scripting)
1. Go to the CELLS → talk to the PRISONER → *"The witness? They've got him
   in interrogation right now."* → points you to interrogation.
2. INTERROGATION is in use / locked. Go to OBSERVATION, watch through the
   glass: the cast's overheard talk → the case file is in EVIDENCE on a
   hidden weighted shelf (chain of custody, badge 57 seed).
3. EVIDENCE (needs the keycard Vance drops at reception): slide the shelf,
   weight-swap the package → the murder weapon, badge 57 = the CAPTAIN.
4. CAPTAIN'S OFFICE: 3 birthday photos → dog's b'day 0806.
5. LOCKER ROOM: crack the captain's locker (0806) on the clock wall → it
   swings out, revealing the HIDDEN PASSAGE to the cells (`captain_is_guilty`).

### The solve (endgame — LOCKED 2026-07-25, TO BUILD)

**The murder mechanic (why it looks impossible).**
- The escort (CAPTAIN + INVESTIGATOR) walks the WITNESS into the cells and
  leaves interrogation EARLY — **~1:00** (t60), reaching the cells ~1:57.
  You can be present; the escorts just refuse you ("This one's ours"). NO
  hard lockout — being in the cell block is allowed and in fact intended.
- The CAPTAIN and INVESTIGATOR both come back OUT and leave. The witness is
  now alone in the cell.
- The CAPTAIN doubles back to the LOCKER ROOM and takes the HIDDEN PASSAGE.
  **The kill is at 3:00 (0:00 on the countdown).** The passage is sealed to
  the player until they crack the locker, so on a blind run the captain
  "vanishes" (not in the locker room if you follow) and the witness dies in
  a sealed cell with only an unarmed prisoner. Impossible — the killer comes
  through the wall.

**The DISCOVERY beat — waiting in the cells is a REAL clue, not a trap.**
- The player's natural instinct is "I'll just wait in the cells at midnight
  and catch him." We REWARD that instead of walling it off. The first time
  you're in the CELLS during ~2:50–3:00, you witness the impossible death up
  close: a muzzle-flash comes from **inside the wall**, the witness drops,
  and you're standing right there and STILL couldn't stop it — the shooter
  is behind solid concrete. Sets `saw_wall_shot` + a journal beat: *"The
  shot came from inside the wall. There's a way in there I can't see."* This
  is what points you at the passage. (You witnessed it but can't reach or
  prove it — so you go find the passage and get to HIS side.) Then the loop
  resets as normal (you didn't stop it).

**The intercept — the win path (PROOF-GATED).**
- Trigger requires **`captain_is_guilty`** (you cracked locker 0806) AND the
  player being in the LOCKER ROOM during the window **2:45–3:00** (t165–180).
  When both are true the **loop clock FREEZES** (we do not let it tick to
  0:00) and the confrontation fires. Without the proof, nothing happens —
  being in the locker room does nothing and the murder proceeds (restart).
  You cannot stumble into the ending; the knowledge is the key.

**First confrontation ALONE = a TAUGHT death.**
- Intercept in the window WITH proof but WITHOUT the rookie staged → the
  captain kills YOU. Teaching line: *"I can't take him alone — my word
  against his and I'm the one who ends up in a cell. I need someone who
  lives to see this."* → points at the ROOKIE. Restart.

**Final run — bring the ROOKIE.**
- After the lesson, a new dialogue option recruits the ROOKIE (he's begged
  to help all game); he then FOLLOWS the player. Lead him to the locker room
  and stage him hidden. Intercept the captain in the 2:45–3:00 window with
  the rookie present → the captain is caught / confesses, the rookie steps
  in as the living witness → **`loop_broken`**, the witness LIVES → credits.
- NO physical recorder. The rookie IS the evidence (a living witness beats a
  tape, and it pays off his whole arc).

**New endgame flags:** `captain_endgame` (captain diverts to locker once
guilty-known), `have_rookie` (recruited/following), `rookie_staged` (hidden
in locker room), `taught_death_seen` (lesson learned), `loop_broken` (win).

## The precinct (rebuilt 2026-07-23)

World coords; every room is a self-contained scene in `scenes/rooms/`:

| Room | Pos | Size | Notes |
|---|---|---|---|
| Bullpen | (0,0) | **20×10** | START. 2 cam zones (west/east shots). Desks, vending machine, Daniels' keycard desk |
| Lobby | (0,10) | 10×10 | Reception desk, waiting bench + patron, EXIT south (green glow, exit_trigger) |
| Captain's office | (-10,-10) | 10×10 | Dutch 5°. 3 birthday photos: daughter MAR 12, wife JUL 30, dog AUG 6 |
| Evidence | (0,-10) | 10×10 | KEYCARD-GATED (per-loop pickup). Case file 44-C |
| Hall 1 | (7,-17) | 4×24 | Long telephoto shot. 2 security cameras — the camera-dodge puzzle |
| Interrogation | (0,-20) | 10×10 | LOCKED ALL GAME (captain inside). Mirror wall north |
| Observation | (0,-27) | 10×4 | show_neighbors ON — see interrogation through the two-way glass. Feed panel teaches the camera gap |
| Hall 2 | (17.5,0) | 15×4 | Cells keypad at the east end |
| Locker room | (15,7) | 10×10 | Captain's locker keypad (0806 = the dog), maintenance slip (cells code 4471) |
| Shooting range | (15,-7) | 10×10 | Sgt. Tally + counter — FPS minigame TO BUILD |
| Cells | (30,0) | 10×10 | flag_gate on `cells_unlocked` (permanent — Deathloop clause) |

Rooms own ALL four walls (interpenetrating at ±4.97, 6cm stagger);
door gaps are cut per wall. NPC waypoints use spot names
("Bullpen/DoorEvidence") so rooms can move freely in the editor.

## Cast

- **Detective** (player) — Detective_Male_01.
- **Rookie Petty** — opens every loop with the 2-hour-old coffee; THE final key.
- **Receptionist Rosa** — front desk; 0:40 phone call (`overheard_call`).
- **Witness** — escorted through the bullpen on loop 0; behind the glass after (talk through the observation window).
- **The Captain** — locked in interrogation all night; only his voice through the door.
- **Officer Daniels** — bullpen↔evidence circuit; his keycard is stealable while he walks it.
- **Officer Vance** — LEAVES in the first ~20s ("I left an hour ago."). Later we realize we need him — catch him early. `saw_vance_leave`.
- **Sgt. Tally** — range master; beat his 40 on the range game → info.
- **Lobby patron** — stolen-bicycle guy on the bench. Comic beat / clue-holder.
- TODO: ambient beat cops/detectives once meshes + separate HAIR meshes (in the FBX packs) are wired; rig editor-preview wanted so characters show in the editor.

## Knowledge vs. holdings (core economy)

- **Flags** = knowledge. Permanent across loops; fill the case file.
- **Loop flags** (`per_loop` on interactable/flag_gate) = what you HOLD.
  Cleared every restart by the clock — the perfect run must re-collect
  them against the 3:00. Current: **Daniels' evidence keycard**.
- Permanent world-state (Deathloop clause, sparingly): cells door
  stays open once `cells_unlocked`.

## Puzzle chains

1. ✅ **Cells**: slip (locker room) → 4471 → hall-2 keypad → open forever.
2. ✅ **Captain's locker**: 3 photos → the DOG's birthday → 0806. Contents TBD (tie to the murder?).
3. ✅ **Evidence access**: steal Daniels' keycard (per-loop!) while he's on his circuit.
4. **Camera dodge** (half-built): feed panel teaches `know_camera_gap` — hall-1 cameras look away during every countdown minute ending in 5. TO BUILD: sweep visual, caught-consequence, observation door gated on the dash.
5. ✅ **Evidence weight swap**: propshelf1-3 slide individually (sliding_shelf.gd); the package hides behind the MIDDLE shelf (propshelf2). Counterweight = a bag of chips from the bullpen vending machine (shake it: 1st interact = seen_stuck_snack, 2nd = have_chips per-loop). Bare grab 1st time = know_weight_trap warning; bare grab after = alarm→restart; grab WITH chips = clean swap (consumes have_chips, sets found_murder_weapon).
6. **Range game**: first-person shooting mini; beat Tally's 40 → he talks. TO BUILD.
7. **Vance**: something he knows is crucial; he's gone in 20s — a tight window every loop. Hook is in.
8. **Snack chain**: stuck PUFFY STARS bag (`seen_stuck_snack`) → learn who eats them → they wanted a snack in their last minutes. Owner TO PLACE.
9. Wanted: one thing that becomes UNAVAILABLE at a fixed time, one room you get KICKED OUT of at a fixed moment.

## Systems inventory

| System | File | Notes |
|---|---|---|
| Tuning | `scripts/game/tuning.gd` | LOOP_LENGTH 180, WALK/RUN_PACE, INTERACT_RANGE, CELLS_CODE — single source |
| Loop clock | `scripts/game/loop_clock.gd` | countdown, hold-R, tick/tock swell 30s + heartbeats 15s, clears loop-flags |
| Flags | `scripts/game/flags.gd` | permanent + per-loop dicts; listeners drive journal toasts |
| Rooms / cam zones | `room.gd`, `cam_zone.gd` | isolation, local-aimed cams; bullpen has 2 zones |
| Flag gates | `flag_gate.gd` | doors opened by flags (or per-loop holdings); locked_line teaches |
| Exit trigger | `exit_trigger.gd` | front door: loop-0 goal / post-intro refusal |
| Interactables | `interactable.gd` | examine → flag; pickup vanish; per_loop holdings |
| Keypads | `keypad.gd` + `ui/keypad_ui.gd` | cells (Tuning code), captain's locker 0806 |
| NPCs | `npc.gd` | spot schedules on the clock; default = stand where placed |
| Rookie | `junior_cop.gd` | clock-based start, flag variants, speeds up per loop |
| Intro | `intro_director.gd` | loop-0 beats all clock-based; eyelid wake every loop; witness head-tracking |
| Objective HUD | `ui/objective.gd` | top-right task line, group "objective" |
| Journal | `ui/journal.gd` | CASE FILE, vertical column fill, entry toasts |
| Dialogue/menu/lose/intercom/arrow/credits | `ui/*` | menu Esc blocked during dialogue & death fade |

## Presentation rules

10×10 rooms, 4m corridors, walls 3m, cameras 2.2–2.8m, FOV 45–55
(hall1 38, cells 30 telephoto). One signature shot per room. Near-black
ambient + one hot pool per room; volumetric shafts. NO roof — the void
is the ceiling. Crimson Text / Fira Code (terminals) / Special Elite
(stencils, title). UI left, −8°; dither layer 100, all UI above it.
Walk sfx positional; tick-tock + heartbeats close each loop.

## Next 3 days (goal list, set 2026-07-23)

**Day 1 — make the precinct sing**
- Editor-visible characters (@tool rig preview) + separate hair meshes.
- Camera-dodge puzzle complete; interrogation barks audible through the observation glass.
- Art pass rolling: Synty wall/floor textures into room scenes (started: hall2).

**Day 2 — the mystery's spine**
- DECIDE the murder: who, how, what stops it.
- Weight-swap puzzle; locker contents; snack owner; Vance's role; range minigame.
- Time-gated item + kick-out event.

**Day 3 — the test**
- Accusation fill-in-the-blank UI + win screen (credits.open()).
- Perfect-run tuning (all per-loop pickups doable inside 3:00).
- Polish: hair, doors, per-room audio beds (benched ambiences in audio/).

## Open questions

- The murder (killer / method / intervention) — everything hangs on this.
- Captain's locker contents; Tally's info; snack-lover identity; Vance's secret.
- Witness-through-glass talk: keep normal interact range through the pane?
- Vance/RangeMaster meshes are Daniels clones — pick distinct cops + hair.
- Settings saves to disk — post-jam.

## Loop-0 sequence + core mystery (locked 2026-07-24)

**Loop origin:** the witness (a Criminal_Male_01 we saved in a past loop)
thanks the detective and presses a FAMILY HEIRLOOM into his hand - the
source of the loop ("the only thing that keeps me coming back").
`bound_promise` flag.

**The mystery, stated simply:** witness alive at 11:57 (interrogation),
dead in the CELLS by midnight. SOMEONE IN THE PRECINCT killed him. The
player is signing out at the lobby when it happens, so they DON'T see
it - everyone near the cells is a suspect. The captain/detective/witness
stay TOGETHER the whole time (do NOT have the captain visibly leave -
players would cross him off; the not-seeing IS the mystery).

**Clock:** counts UP 11:57:00 -> 12:00:00 (done in loop_clock.gd:
start_hour/start_minute exports, `time` still = elapsed seconds 0-180).

**Loop-0 timeline (t = elapsed seconds, 11:57:00 = t0):**
- t0 11:57:00 - wake in bullpen; cast already in interrogation
- t3 11:57:03 - trinket beat: witness thanks you, gives heirloom (bound_promise)
- t30 11:57:30 - VANCE (repurposed as the evidence clerk) leaves evidence,
  stops at reception, VISIBLY drops his keycard on the desk edge (toggle
  its visibility on), exits. This card REPLACES the bullpen keycard as
  evidence-room access.
- t45ish - rookie coffee beat (bullpen)
- t60-80 11:58:00-20 - Rosa's 1st phone call: she visibly TURNS to the
  phone; the keycard is grabbable ONLY in this 20s window
- t120-140 11:59:00-20 - Rosa's 2nd call, 2nd 20s window
- cast leaves interrogation -> cells (OFFSCREEN, player is at lobby)
- player signs out with Rosa -> time-skip the blabbing
- t180 12:00:00 - GUNSHOT from the cells + ALARM sound, doors unlock
- run to cells: witness dead in CELL 2 (the empty one), 3 NPCs present
  (Captain + Det. Ross + 1 more), walk to body, clue in his hand -> restart

**Rules:**
- Rosa is ALWAYS at the front desk (no schedule wander).
- Grabbing the keycard OUTSIDE the phone windows = she catches you ->
  loop restarts (reuse lose_screen.play_lose()).
- ALL doors blocked during Loop 0 EXCEPT the lobby. Hall2 + cells UNLOCK
  at the gunshot event so the player can reach the body.
- Vance = the evidence clerk (repurpose existing NPC; his locker already
  reads "cleared out, not coming back tonight").

**Build status:** clock flip DONE. Everything else (intro_director
rewrite, Vance/clerk keycard drop, Rosa phone-turn windows, timed keycard
theft, cast interrogation->cells schedules, door gating, death scene)
is TO BUILD - big coordinated multi-file change, do in a fresh session.
