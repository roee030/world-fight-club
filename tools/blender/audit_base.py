import bpy
from pathlib import Path

root = Path(r"D:\election world fight")
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root / "assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"))
for obj in bpy.context.scene.objects:
    print("AUDIT", obj.name, obj.type, "parent=", obj.parent.name if obj.parent else "", "mods=", [m.type for m in obj.modifiers])
    if obj.type == 'MESH':
        print("BOUNDS", obj.name, [tuple(round(v, 4) for v in c) for c in obj.bound_box])
        print("GROUPS", obj.name, [(g.index, g.name) for g in obj.vertex_groups])
arm = bpy.data.objects.get("Armature")
for name in ["Head", "hand_l", "hand_r", "foot_l", "foot_r", "spine_03"]:
    bone = arm.data.bones.get(name)
    print("BONE", name, tuple(round(v, 4) for v in bone.head_local), tuple(round(v, 4) for v in bone.tail_local))
