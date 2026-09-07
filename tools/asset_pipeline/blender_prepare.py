"""Blender-only static asset normalization, export and review render."""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

directory = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
spec = json.loads((directory / 'manifest.json').read_text())['spec']
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(directory / 'raw.glb'))
if any(o.type == 'ARMATURE' or (o.animation_data and o.animation_data.action) for o in bpy.context.scene.objects):
    raise RuntimeError('This preparer is for static generated meshes. Rigged/animated assets need a separate import path.')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if not meshes:
    raise RuntimeError('No mesh objects in GLB.')
# Bake world transforms while preserving geometry before joining all static parts.
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.object
original_triangles = sum(len(p.vertices)-2 for p in obj.data.polygons)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.00001)
bpy.ops.object.mode_set(mode='OBJECT')
triangles = sum(len(p.vertices)-2 for p in obj.data.polygons)
if triangles > spec['triangles']:
    modifier = obj.modifiers.new('Game triangle budget', 'DECIMATE')
    modifier.ratio = spec['triangles'] / triangles
    bpy.ops.object.modifier_apply(modifier=modifier.name)
if not obj.data.vertices or any(not math.isfinite(c) for v in obj.data.vertices for c in v.co):
    raise RuntimeError('Mesh is empty or contains non-finite coordinates.')
low = Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)])
high = Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
if high.z-low.z < 1e-6:
    raise RuntimeError('Asset has no height; inspect orientation before preparing.')
scale = spec['height'] / (high.z-low.z)
offset = Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
turn = Matrix.Rotation(math.radians(spec['yaw']), 3, 'Z')
for vertex in obj.data.vertices:
    vertex.co = turn @ ((vertex.co-offset)*scale)
obj.name = 'AssetMesh'
bpy.context.scene.cursor.location = (0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.file.pack_all()
bpy.ops.export_scene.gltf(filepath=str(directory/'prepared.glb'), export_format='GLB',
                          use_selection=True, export_animations=False, export_cameras=False, export_lights=False)
scene = bpy.context.scene
for other in list(scene.objects):
    if other != obj:
        bpy.data.objects.remove(other, do_unlink=True)
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.4,0.4,0.4,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.7
scene.view_settings.view_transform = 'Standard'
bpy.context.view_layer.update()
bounds = [obj.matrix_world @ Vector(p) for p in obj.bound_box]
low = Vector([min(v[i] for v in bounds) for i in range(3)])
high = Vector([max(v[i] for v in bounds) for i in range(3)])
center = (low+high)/2
size = max(high-low)
for name, direction, power in [('Key',(2,3,4),1000),('Fill',(-3,2,2),650),('Rim',(1,-3,3),750)]:
    data = bpy.data.lights.new(name,'AREA')
    data.energy = power*size*size
    data.size = size*3
    light = bpy.data.objects.new(name,data)
    scene.collection.objects.link(light)
    light.location = center + Vector(direction)*size
    light.rotation_euler = (center-light.location).to_track_quat('-Z','Y').to_euler()
data = bpy.data.cameras.new('AssetReviewCamera')
camera = bpy.data.objects.new('AssetReviewCamera',data)
scene.collection.objects.link(camera)
camera.location = center+Vector((-2,3,1))*size
camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
data.type = 'ORTHO'
data.ortho_scale = size*1.35
scene.camera = camera
scene.render.filepath = str(directory/'preview.png')
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(directory/'prepared.blend'))
report = {'source_triangles': original_triangles,
          'triangles': sum(len(p.vertices)-2 for p in obj.data.polygons),
          'dimensions_blender_xyz': list(high-low), 'height_m': high.z-low.z,
          'origin': 'bottom center', 'yaw_degrees': spec['yaw'],
          'material_slots': len(obj.data.materials),
          'textures': [{'name': i.name, 'size': list(i.size)} for i in bpy.data.images if i.source == 'FILE'],
          'rigged': False, 'collision': 'none; add simple collision in the game scene as needed'}
(directory/'asset-report.json').write_text(json.dumps(report,indent=2))
print('ASSET_PREPARED')
