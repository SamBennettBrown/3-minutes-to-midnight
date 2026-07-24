import bpy
import os

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIMS = os.path.join(PROJECT, "ANIMATION_Base_Locomotion_SourceFiles_v3", "SourceFiles")
RIVALS = os.path.join(PROJECT, "PolygonFantasyRivals_Source_Files", "Source_Files", "Characters", "Characters")
OUT_DIR = os.path.join(PROJECT, "tools", "converted")
os.makedirs(OUT_DIR, exist_ok=True)

# Fantasy Rivals (Unreal-style) bone names -> Polygon animation rig names.
# Renaming at conversion time lets Rivals meshes dress Polygon anim rigs.
RIVALS_TO_POLYGON = {
    "Pelvis": "Hips",
    "spine_01": "Spine_01", "spine_02": "Spine_02", "spine_03": "Spine_03",
    "neck_01": "Neck", "head": "Head",
    "clavicle_l": "Clavicle_L", "UpperArm_L": "Shoulder_L",
    "lowerarm_l": "Elbow_L", "Hand_L": "Hand_L",
    "clavicle_r": "Clavicle_R", "UpperArm_R": "Shoulder_R",
    "lowerarm_r": "Elbow_R", "Hand_R": "Hand_R",
    "Thigh_L": "UpperLeg_L", "calf_l": "LowerLeg_L",
    "Foot_L": "Ankle_L", "ball_l": "Ball_L", "toes_l": "Toes_L",
    "Thigh_R": "UpperLeg_R", "calf_r": "LowerLeg_R",
    "Foot_R": "Ankle_R", "ball_r": "Ball_R", "toes_r": "Toes_R",
    "eyes": "Eyes", "eyebrows": "Eyebrows",
}

# Polygon animation rig names -> Godot humanoid names, for dressing
# meshes that come from Godot-converted packs (their skins bind humanoid)
POLYGON_TO_HUMANOID = {
    "Hips": "Hips", "Spine_01": "Spine", "Spine_02": "Chest",
    "Spine_03": "UpperChest", "Neck": "Neck", "Head": "Head", "Jaw": "Jaw",
    "Clavicle_L": "LeftShoulder", "Shoulder_L": "LeftUpperArm",
    "Elbow_L": "LeftLowerArm", "Hand_L": "LeftHand",
    "Clavicle_R": "RightShoulder", "Shoulder_R": "RightUpperArm",
    "Elbow_R": "RightLowerArm", "Hand_R": "RightHand",
    "UpperLeg_L": "LeftUpperLeg", "LowerLeg_L": "LeftLowerLeg",
    "Ankle_L": "LeftFoot", "Ball_L": "LeftToes",
    "UpperLeg_R": "RightUpperLeg", "LowerLeg_R": "RightLowerLeg",
    "Ankle_R": "RightFoot", "Ball_R": "RightToes",
}


def convert(src, dst, rename=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src)
    if rename == "STRIP_PREFIX":
        # Mixamo bones arrive as "mixamorig:Hips" - strip to "Hips"
        stripped = 0
        for obj in bpy.data.objects:
            if obj.type == "ARMATURE":
                for bone in obj.data.bones:
                    if ":" in bone.name:
                        bone.name = bone.name.split(":")[-1]
                        stripped += 1
        print("BLEND stripped prefix on %d bones" % stripped)
    elif rename:
        renamed = 0
        for obj in bpy.data.objects:
            if obj.type == "ARMATURE":
                for bone in obj.data.bones:
                    if bone.name in rename:
                        bone.name = rename[bone.name]
                        renamed += 1
        print("BLEND renamed %d bones" % renamed)
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
    print("BLEND exported", dst)


# command-line mode:  blender --background --python convert_fbx.py -- SRC DST [rivals|humanoid|none]
import sys

RENAMES = {"rivals": RIVALS_TO_POLYGON, "humanoid": POLYGON_TO_HUMANOID,
           "mixamo": "STRIP_PREFIX", "none": None}

if "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
    src_path = args[0]
    dst_path = args[1]
    rename_key = args[2] if len(args) > 2 else "none"
    convert(src_path, dst_path, RENAMES.get(rename_key))
    print("BLEND done")
else:
    print("BLEND usage: blender --background --python convert_fbx.py -- SRC DST [rivals|humanoid|none]")
