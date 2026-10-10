import bpy
import math
from pathlib import Path

ROOT = Path(r"D:\election world fight")
SOURCE = ROOT / "assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"
OUTPUT_DIR = ROOT / "assets/characters/rigged/custom/bennet"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
SOURCE_DIR = ROOT / "tools/blender-source/bennet"
SOURCE_DIR.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))

armature = bpy.data.objects["Armature"]
body = bpy.data.objects["SuperHero_Male"]

def material(name, rgba, metallic=0.0, roughness=0.6):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.metallic = metallic
    mat.roughness = roughness
    return mat

shirt_mat = material("Bennet_KravMaga_Shirt", (0.012, 0.018, 0.028, 1.0), 0.01, 0.72)
pants_mat = material("Bennet_KravMaga_Pants", (0.025, 0.038, 0.055, 1.0), 0.01, 0.68)
black = material("Bennet_Protective_Black", (0.008, 0.012, 0.018, 1.0), 0.12, 0.48)
cyan = material("Bennet_Cyan_Accent", (0.0, 0.65, 0.92, 1.0), 0.16, 0.38)
white = material("Bennet_Teeth", (0.92, 0.90, 0.82, 1.0), 0.0, 0.36)

def dominant_group(obj, vertex):
    if not vertex.groups:
        return ""
    group = max(vertex.groups, key=lambda item: item.weight)
    return obj.vertex_groups[group.group].name

def clothing_copy(name, allowed, mat, inflate=0.004):
    obj = body.copy()
    obj.data = body.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    body.select_set(False)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    for vertex in obj.data.vertices:
        vertex.select = dominant_group(obj, vertex) not in allowed
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.delete(type='VERT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.transform.shrink_fatten(value=inflate, use_even_offset=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.select_set(False)
    return obj

shirt_bones = {"spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r"}
pants_bones = {"pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"}
glove_bones = {name for name in body.vertex_groups.keys() if "hand_" in name or any(token in name for token in ["thumb_", "index_", "middle_", "ring_", "pinky_"])}
shoe_bones = {"foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"}

clothing_copy("KravMaga_Shirt", shirt_bones, shirt_mat, 0.006)
clothing_copy("KravMaga_Pants", pants_bones, pants_mat, 0.007)
clothing_copy("KravMaga_Gloves", glove_bones, black, 0.006)
clothing_copy("KravMaga_Boots", shoe_bones, black, 0.010)

# Narrow and slightly lengthen the head for Bennet's recognizable silhouette.
head_index = body.vertex_groups["Head"].index
for vertex in body.data.vertices:
    head_weight = next((g.weight for g in vertex.groups if g.group == head_index), 0.0)
    if head_weight > 0.30:
        vertex.co.x *= 0.88
        vertex.co.y = 0.017 + (vertex.co.y - 0.017) * 0.94
        vertex.co.z = 1.64 + (vertex.co.z - 1.64) * 1.035

def rigid_mesh(obj, bone_name):
    obj.parent = armature
    modifier = obj.modifiers.new("Armature", 'ARMATURE')
    modifier.object = armature
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')

def cube(name, location, scale, mat, bone="Head", rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    rigid_mesh(obj, bone)
    return obj

# Two humorous tefillin boxes, head band and rear straps.
cube("Tefillin_Left", (-0.073, 0.010, 1.825), (0.032, 0.030, 0.035), black, rotation=(0.08, -0.15, -0.12))
cube("Tefillin_Right", (0.073, 0.010, 1.825), (0.032, 0.030, 0.035), black, rotation=(0.08, 0.15, 0.12))
bpy.ops.mesh.primitive_torus_add(major_radius=0.112, minor_radius=0.007, major_segments=32, minor_segments=8, location=(0, 0.017, 1.705))
band = bpy.context.object
band.name = "Tefillin_HeadBand"
band.data.materials.append(black)
rigid_mesh(band, "Head")
cube("Tefillin_Strap_L", (-0.027, 0.115, 1.515), (0.009, 0.005, 0.145), black)
cube("Tefillin_Strap_R", (0.027, 0.115, 1.515), (0.009, 0.005, 0.145), black)

# Two separate front teeth with the small signature gap.
cube("FrontTooth_L", (-0.014, -0.139, 1.641), (0.011, 0.006, 0.018), white)
cube("FrontTooth_R", (0.014, -0.139, 1.641), (0.011, 0.006, 0.018), white)

# Cyan character marks on the chest, weighted to the chest bone.
cube("KravMaga_CyanMark_L", (-0.115, -0.145, 1.355), (0.055, 0.006, 0.009), cyan, "spine_03", rotation=(0, 0.20, 0.25))
cube("KravMaga_CyanMark_R", (0.115, -0.145, 1.355), (0.055, 0.006, 0.009), cyan, "spine_03", rotation=(0, -0.20, -0.25))

# Rigid accessories are authored here for reference but exported separately by
# Godot as BoneAttachment3D nodes. Exporting them as one-bone skins can produce
# invalid inverse binds after glTF round-tripping and giant stretched triangles.
for rigid_name in [
    "Tefillin_Left", "Tefillin_Right", "Tefillin_HeadBand",
    "Tefillin_Strap_L", "Tefillin_Strap_R", "FrontTooth_L", "FrontTooth_R",
    "KravMaga_CyanMark_L", "KravMaga_CyanMark_R",
]:
    obj = bpy.data.objects.get(rigid_name)
    if obj is not None:
        bpy.data.objects.remove(obj, do_unlink=True)

# The base eye and eyebrow meshes use separate skins whose inverse bind data is
# not stable after the Blender glTF round trip. They caused the giant triangles
# seen in the model lab, so the clean modeling baseline intentionally excludes
# them. Facial details will be rebuilt later as non-skinned head attachments.
for unstable_name in ["Eyes", "Eyebrows"]:
    obj = bpy.data.objects.get(unstable_name)
    if obj is not None:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "bennet-krav-maga.blend"))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_DIR / "bennet-krav-maga.glb"),
    export_format='GLB',
    export_skins=True,
    export_animations=False,
    export_yup=True,
)
print("BUILT", OUTPUT_DIR / "bennet-krav-maga.glb")
