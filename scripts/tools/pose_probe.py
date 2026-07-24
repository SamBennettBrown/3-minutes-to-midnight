import bpy
import math
import os

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIMS = os.path.join(PROJECT, "ANIMATION_Base_Locomotion_SourceFiles_v3", "SourceFiles", "Animations", "Polygon")

CLIPS = [
    os.path.join(ANIMS, "Masculine", "Locomotion", "Run", "A_Run_F_Masc.fbx"),
    os.path.join(ANIMS, "Masculine", "Idle", "A_Idle_Standing_Masc.fbx"),
]
BONES = ["Shoulder_L", "Elbow_L", "UpperLeg_R", "Hips"]


for clip in CLIPS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=clip)
    arm = None
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            arm = obj
            break
    if arm is None:
        print("POSE no armature in", clip)
        continue
    scene = bpy.context.scene
    action = arm.animation_data.action if arm.animation_data else None
    f_start, f_end = (1, 21)
    if action is not None:
        f_start, f_end = int(action.frame_range[0]), int(action.frame_range[1])
    print("POSE clip %s action frames %d-%d" % (os.path.basename(clip), f_start, f_end))
    for bone_name in BONES:
        if bone_name not in arm.pose.bones:
            print("POSE   %s: missing" % bone_name)
            continue
        angles = []
        for f in range(f_start, f_end + 1, max(1, (f_end - f_start) // 8)):
            scene.frame_set(f)
            pb = arm.pose.bones[bone_name]
            q = pb.matrix_basis.to_quaternion()
            angles.append(round(math.degrees(q.angle), 1))
        print("POSE   %s deviation-from-rest per frame: %s" % (bone_name, angles))
