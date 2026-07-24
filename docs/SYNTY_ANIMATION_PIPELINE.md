# The Synty Animation Pipeline (Godot)

*How to make any Synty character play any Synty animation — and why
every step exists. Written after one very long night of discovering
all of this the hard way.*

---

## Part 1: The mental model (read this once, everything else follows)

A skinned character is **three separate things** pretending to be one:

1. **The mesh** — the visible shape (vertices, triangles, textures).
2. **The skeleton (rig)** — invisible bones in a parent-child tree.
   Every bone has a **rest pose**: where it sits when nothing animates it.
3. **The skin** — the glue. For each mesh vertex it records *which bones
   pull on it* and how much. Critically, the skin refers to bones **by
   name**, and carries **bind poses** — baked-in math describing where
   the bones were when the mesh was fitted to them.

An **animation** is just a list of curves: "bone `Hips` should rotate
like *this* over time." It also targets bones **by name**.

So for animation to work, three things must agree:
- The **names** the animation uses = the names the skeleton has.
- The **rest poses** the animation was authored against = the rest
  poses the skeleton has (a rotation value means something *relative
  to rest*; different rest = same numbers, different pose).
- The **bind poses** the skin carries = the skeleton it's attached to.

**Every failure we ever hit was one of these three disagreeing.**

### Why Synty makes this hard

Synty ships rigs in (at least) three "dialects":

| Dialect | Bone names look like | Where you see it |
|---|---|---|
| Polygon (original) | `Shoulder_L`, `Elbow_L`, `Ankle_L` | Animation packs, mannequin, most classic packs' Source Files |
| Unreal-style | `UpperArm_L`, `calf_l`, `Pelvis` | Fantasy Rivals (and other newer packs) |
| Godot humanoid | `LeftUpperArm`, `LeftLowerLeg` | Synty's Godot-converted packs (PolygonDungeon) |

On top of that, **Godot's built-in FBX importer reads Synty FBXs
slightly inconsistently between files** — subtle enough that even
same-family rigs come out disagreeing about rest poses. This is why
"it should just work" never did.

### The two big rules

1. **Never animate the Godot-converted pack prefabs** (e.g. the
   PolygonDungeon `Character_*.tscn` files). Their meshes do not
   deform — proven by directly rotating bones and watching nothing
   happen. They're display statues. Always start from Source Files FBXs.
2. **Never let Godot's FBX importer touch anything you want animated.**
   Route every FBX through Blender first. One converter = one
   consistent interpretation = rigs that actually agree.

---

## Part 2: The recipe

### The one-command version (use this day-to-day)

```powershell
# an animation clip:
.\tools\synty_import.ps1 -Source "path\to\A_Whatever.fbx" -Type anim

# a character (Polygon-rig packs):
.\tools\synty_import.ps1 -Source "path\to\SK_Character.fbx" -Type character

# a character from Fantasy Rivals (Unreal-style bones):
.\tools\synty_import.ps1 -Source "path\to\SK_Character.fbx" -Type character -Dialect rivals
```

That's the whole process. One command per asset: it converts through
Blender, pre-writes the correct Godot import config (all the flags
below), and imports — output lands in `scripts/tools/retarget/<name>_rt.glb`,
immediately compatible with everything else in that folder. It only
ever creates new files, so it can't break existing work. To batch a
folder, loop it:

```powershell
Get-ChildItem "SomePack\Idle" -Filter *.fbx -Recurse |
    ForEach-Object { .\tools\synty_import.ps1 -Source $_.FullName -Type anim }
```

The manual steps below are what the script does internally — kept for
understanding and for debugging when something new goes wrong.

### One-time setup (already done in this project)
- Blender installed (used headless — you never open its UI).
- `scripts/tools/convert_fbx.py` — the converter script with bone-rename maps.
- `anims/synty_bone_map.tres` — maps Polygon bone names → Godot's
  humanoid profile. This is the "Rosetta stone."

### Adding a new ANIMATION (any clip from any Synty animation pack)

1. **Convert FBX → GLB via Blender.** Edit the bottom of
   `scripts/tools/convert_fbx.py` to point at the clip, then:
   ```
   blender --background --python scripts/tools/convert_fbx.py
   ```
   Output goes to `scripts/tools/retarget/yourclip_rt.glb`.

2. **Let Godot import it once** (open the editor, or headless:
   `godot --headless --path . --import`). This generates
   `yourclip_rt.glb.import`.

3. **Edit that `.import` file** — replace `_subresources={}` with:
   ```
   _subresources={
   "nodes": {
   "PATH:Armature/Skeleton3D": {
   "retarget/bone_map": Resource("res://anims/synty_bone_map.tres"),
   "retarget/rest_fixer/fix_silhouette/enable": true
   }
   }
   }
   ```
   and change `animation/remove_immutable_tracks=true` → `false`.

4. **Reimport** (focus the editor again, or `--import`). Done — the
   clip is now in the universal humanoid format.

**Why each flag:**
- `bone_map` → renames bones AND converts rotation values into the
  shared humanoid standard.
- `fix_silhouette` → the animation rig's rest pose is *arms-down*,
  but characters rest in *T-pose*. Without this, the arms-down
  baseline is silently discarded → everything T-poses. (This one flag
  cost us three hours.)
- `remove_immutable_tracks=false` → the optimizer deletes "unchanging"
  channels; subtle idles fall under its threshold and become statues.

### Adding a new CHARACTER (from any Source Files FBX)

Same four steps, with two differences:
- In `convert_fbx.py`, pass the rename map for its dialect
  (`RIVALS_TO_POLYGON` for Fantasy Rivals; none needed for
  Polygon-rig characters).
- In the `.import` block: no `fix_silhouette`, and the node key may be
  `"PATH:Root/Skeleton3D"` instead of `"PATH:Armature/Skeleton3D"`
  (structure varies; include both keys — Godot keeps the right one.
  `scripts/tools/tree_probe.gd` prints a scene's structure if unsure).

### Playing: it's just Godot now

After retargeting, both character and clip speak "GeneralSkeleton /
humanoid." Any clip plays on any character with a vanilla
AnimationPlayer — the track paths simply resolve. In this project,
`sprites/model_billboard.gd` does it (see `_setup_booth`, "direct
mode") and adds two conveniences:
- `_prep_clip()` trims the first 0.1s — every Synty clip opens with a
  T-pose calibration frame that hitches loops.
- `_apply_material()` — Blender can't find Synty's textures (the FBXs
  reference files Synty never shipped), so characters arrive white.
  We re-apply the pack's shared atlas material at runtime
  (`materials/fantasy_rivals_01_a.tres` for anything from Rivals).

---

## Part 3: Troubleshooting table (earned the hard way)

| Symptom | Cause | Fix |
|---|---|---|
| Character T-poses, no motion at all | Names don't match / clip not retargeted | Check both sides went through the bone map |
| T-pose arms, legs animate | Missing `fix_silhouette` on the animation import | Add the flag, reimport |
| Pose right but frozen solid | `remove_immutable_tracks` ate the subtle channels | Set it `false`, reimport |
| Full-body jitter | Two AnimationPlayers fighting over one skeleton | Deactivate the model's bundled player |
| Hitch when the loop restarts | T-pose calibration frame at clip start | Trim first 0.1s (`_prep_clip`) |
| Mesh in pieces / thin line / invisible | Skin bind poses from a different skeleton | Don't transplant meshes across rigs — retarget both sides instead |
| Character is 100× too big | GLB scale convention | Scale by hips height (booth does it automatically) |
| Character is white | Textures lost in conversion | Apply the pack's atlas material |
| "It looks frozen" on an idle | The clip is authored with 1–2° of motion | It's working — pick a gesture clip (KickGround, Drink, etc.) |
| Judging a clip from its first frame | Frame 1 is always T-pose | Scrub to the middle |

---

## Part 4: Is it overly complicated?

**The understanding: no.** It's four ideas — names must match, rests
must match, skins can't be transplanted, and one converter must read
everything. That's the whole theory, and it's now yours.

**The daily process: no.** Adding a monster or a clip is: edit two
lines in a Python script, run one command, paste one config block,
reimport. Five minutes, and every step is batchable — converting the
entire 692-clip library or the whole Rivals roster is one loop.

**The discovery: yes, brutally.** The difficulty was never the
pipeline — it was that five independent problems (dead meshes, three
name dialects, importer inconsistency, the silhouette flag, the
track optimizer) were stacked on top of each other, and each one's
symptom (a T-pose) looked identical to the others'. That's why every
forum thread about Synty + Godot animation ends in surrender. Yours
now ends in a pig butcher kicking dirt in a dungeon.
