"""Render the prepared asset from opposite sides, with PBR and plain clay."""
import sys
from pathlib import Path
import bpy
from mathutils import Vector

directory = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(directory/'prepared.blend'))
scene = bpy.context.scene
obj = bpy.data.objects['AssetMesh']
points = [obj.matrix_world @ Vector(p) for p in obj.bound_box]
low = Vector([min(p[i] for p in points) for i in range(3)])
high = Vector([max(p[i] for p in points) for i in range(3)])
center = (low+high)/2
size = max(high-low)
scene.render.resolution_x = scene.render.resolution_y = 512
scene.cycles.samples = 8
scene.view_settings.view_transform = 'AgX'
for light in [o for o in scene.objects if o.type == 'LIGHT']:
    light.data.energy *= 0.15
clay = bpy.data.materials.new('ReviewClay')
clay.use_nodes = True
bsdf = clay.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (.35,.35,.35,1)
bsdf.inputs['Roughness'].default_value = .85
for mode in ('pbr', 'clay', 'clay-recomputed'):
    if mode == 'clay':
        for slot in obj.material_slots:
            slot.material = clay
    if mode == 'clay-recomputed':
        obj.data.normals_split_custom_set([(0,0,0)] * len(obj.data.loops))
        obj.data.update()
    for side, direction in [('front',(-2,3,1)), ('rear',(2,-3,1))]:
        scene.camera.location = center+Vector(direction)*size
        scene.camera.rotation_euler = (center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath = str(directory/f'review-{mode}-{side}.png')
        bpy.ops.render.render(write_still=True)
