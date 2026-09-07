"""UV-map a floor/pump texture pilot, preserving the untextured v1 source."""
import bpy, pathlib, math, json, struct
from mathutils import Vector
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'broken_foundry_v1.blend'))

def textured(name, filename, roughness, metal=0):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value=roughness
    shader.inputs['Metallic'].default_value=metal
    image=bpy.data.images.load(str(HERE/'textures'/filename),check_existing=True)
    image.colorspace_settings.name='sRGB';image.pack()
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    tex.extension='REPEAT';tex.interpolation='Linear'
    tint=(.50,.47,.43,1) if 'Concrete' in name else (.65,.65,.65,1)
    multiply=mat.node_tree.nodes.new('ShaderNodeMixRGB')
    multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1
    multiply.inputs[2].default_value=tint
    mat.node_tree.links.new(tex.outputs['Color'],multiply.inputs[1])
    mat.node_tree.links.new(multiply.outputs[0],shader.inputs['Base Color'])
    return mat

def uv_project(obj, scale, turn=0):
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
    # Box projection in object-local meters, identical texel density across faces.
    for face in obj.data.polygons:
        normal=face.normal
        axis=max(range(3),key=lambda i:abs(normal[i]))
        axes=[i for i in range(3) if i!=axis]
        for loop in face.loop_indices:
            co=obj.data.vertices[obj.data.loops[loop].vertex_index].co
            u,v=co[axes[0]]/scale+.5,co[axes[1]]/scale+.5
            for _ in range(turn):u,v=v,1-u
            uv.data[loop].uv=(u,v)

floor=textured('Pilot_Concrete_Painted','concrete.png',.94)
paint=textured('Pilot_Ochre_Worn','ochre_paint.png',.78,.0)
changed=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    if obj.name.startswith('Courtyard_slab'):
        parts=obj.name.split('_');turn=(int(parts[-1])+int(parts[-2])*3)%4
        obj.data.materials.clear();obj.data.materials.append(floor)
        uv_project(obj,4,turn);changed.append(obj.name)
    elif obj.name.startswith('Side_pump_housing') and obj.location.x < 0 and abs(obj.location.y+7)<.1:
        obj.data.materials.clear();obj.data.materials.append(paint)
        uv_project(obj,3.5);changed.append(obj.name)

# Export only the original scenery meshes, not review cameras/lights.
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'prototype/assets/environment/broken_foundry_v2.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
# Explicit portable color factors keep the preview tint independent of exporter
# recognition of Blender's Multiply node. No image pixels are modified.
glb=ROOT/'prototype/assets/environment/broken_foundry_v2.glb'
raw=glb.read_bytes();length,kind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+length]);tail=raw[20+length:]
for m in doc.get('materials',[]):
    if m.get('name') in ['Pilot_Concrete_Painted','Pilot_Ochre_Worn']:
        m['pbrMetallicRoughness']['baseColorFactor']=[.50,.47,.43,1] if 'Concrete' in m['name'] else [.65,.65,.65,1]
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
glb.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(tail))+struct.pack('<II',len(encoded),kind)+encoded+tail)
scene=bpy.context.scene
scene.render.filepath=str(HERE/'textured-preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'broken_foundry_v2.blend'))
bpy.ops.render.render(write_still=True)
camera=scene.camera
camera.location=(-24,-16,9)
camera.rotation_euler=(Vector((-18,-7,1.5))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=9
scene.render.resolution_x=768;scene.render.resolution_y=768
scene.render.filepath=str(HERE/'pump-texture-detail.png')
bpy.ops.render.render(write_still=True)
(HERE/'textures/pilot-manifest.json').write_text(json.dumps({'changed_objects':changed,'maps':'sRGB color images; scalar roughness; no fabricated normal/height maps','source':'ComfyUI Krea 2 Turbo; graphs and seeds alongside textures','scope':'49 floor slabs and left-front housing at Blender (-18,-7,1.7)','uv':'face projection in local meters; floor 4m per repeat, pump 3.5m'},indent=2))
print('TEXTURE_PILOT_COMPLETE',len(changed))
