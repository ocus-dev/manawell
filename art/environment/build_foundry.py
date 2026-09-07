"""Build an editable scenery kit in an isolated Blender background process.
Blender XY is ground; glTF exports Y-up for Godot. No gameplay collision changes.
"""
import bpy, math, random, pathlib, json
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART = ROOT / 'art/environment'
EXPORT = ROOT / 'prototype/assets/environment'
EXPORT.mkdir(parents=True, exist_ok=True)
random.seed(9062026)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0.0, emission=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .83
    bs.inputs['Metallic'].default_value = metallic
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    return m

concrete = [material('Concrete_%d'%i,(.18+i*.017,.21+i*.016,.23+i*.018)) for i in range(4)]
steel = material('Charcoal_painted_steel',(.085,.12,.145),.45)
edge = material('Worn_steel_edges',(.27,.32,.34),.6)
ochre = material('Guild_ochre',(.58,.33,.085),.25)
rust = material('Oxide_rust',(.29,.12,.055),.15)
black = material('Vent_shadow',(.026,.041,.047))
cyan = material('Mana_cyan',(.06,.7,.78),emission=2)
lamp = material('Amber_status_lamp',(.9,.47,.07),emission=1)
ground = material('Surrounding_ash',(.09,.115,.13))
asset_objects=[]

def finish(obj, name, mat):
    obj.name=name
    obj.data.materials.append(mat)
    asset_objects.append(obj)
    return obj

def box(name, loc, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object; o.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(o,name,mat)
    if bevel:
        mod=o.modifiers.new('Manufactured_edge','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def cylinder(name, loc, radius, depth, mat, direction=None, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=finish(bpy.context.object,name,mat)
    if direction: o.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler()
    return o

def beam(name,a,b,r,mat):
    a,b=Vector(a),Vector(b)
    return cylinder(name,(a+b)/2,r,(b-a).length,mat,b-a)

box('Ash_foundation',(0,3,-.25),(76,72,.3),ground)
# Quiet, traversable floor: tile seams convey scale without covering targets.
for i in range(7):
    for j in range(7):
        box('Courtyard_slab_%d_%d'%(i,j),(-12+i*4,-12+j*4,.045),(3.96,3.96,.09),random.choice(concrete))
for side in [-1,1]:
    for k in range(14):
        box('Safety_dashes',(side*13.5,-13+k*2,.103),(.22,1.0,.015),ochre)
    for y in range(-12,14,4):
        box('Boundary_plinth',(side*14.35,y,.26),(.7,3.8,.52),concrete[1],.06)
    beam('Perimeter_supply_pipe',(side*16,-12,1.0),(side*16,13,1.0),.38,steel)
    for y in range(-11,14,4):
        cylinder('Pipe_collar',(side*16,y,1),.46,.22,edge,(0,1,0))
        box('Pipe_saddle',(side*16,y,.3),(1.2,.5,.6),concrete[0])
    for y in [-7,6,12]:
        box('Side_pump_base',(side*18,y,.3),(3.6,4.3,.6),concrete[1],.1)
        box('Side_pump_housing',(side*18,y,1.7),(2.8,3.5,2.4),ochre,.16)
        for z in [1.1,1.5,1.9,2.3]:
            box('Pump_vent',(side*16.58,y,z),(.045,2.5,.15),black)
        cylinder('Pump_motor',(side*18,y,3.15),.95,.55,steel)
        cylinder('Pump_cap',(side*18,y,3.46),1.01,.08,edge)
        box('Pump_indicator',(side*16.53,y-.9,2.7),(.04,.16,.12),lamp)

# Rear plant silhouettes are outside the existing 28m collision boundary.
for x,y,w,d,h in [(-11,23,9,9,7),(1,27,11,10,10),(13,24,8,9,6)]:
    box('Foundry_block',(x,y,h/2),(w,d,h),concrete[0],.12)
    box('Foundry_crown',(x,y,h+.18),(w+.6,d+.6,.36),steel)
    for px in [x-w/2+.5,x+w/2-.5]:
        box('Structural_rib',(px,y-d/2-.12,h/2),(.6,.7,h+.6),concrete[2])
    for z in [h*.35,h*.7]:
        box('Recessed_window_band',(x,y-d/2-.02,z),(w-1.5,.06,.7),black)
        for wx in range(int(w)-2):
            box('Window_mullion',(x-w/2+1.2+wx,y-d/2-.07,z),(.08,.08,.72),edge)
for x,h in [(-8,13),(-4,16)]:
    cylinder('Smokestack',(x,25,h/2),1.05,h,steel)
    for z in [3,7,11]: cylinder('Stack_band',(x,25,z),1.12,.24,rust)
    cylinder('Stack_rim',(x,25,h),1.16,.25,edge)
for x in [-9,-3,4,10]:
    cylinder('Pressure_vessel',(x,16.9,2.6),1.45,4.5,ochre)
    cylinder('Vessel_top',(x,16.9,4.95),1.6,.25,steel)
    cylinder('Vessel_foot',(x,16.9,.45),1.65,.45,concrete[1])
    for z in [1.3,3.8]: cylinder('Vessel_band',(x,16.9,z),1.5,.16,edge)
    beam('Vessel_riser',(x+1.65,16.9,.6),(x+1.65,16.9,4.6),.13,steel)
beam('Rear_header_pipe',(-15,19,5.5),(15,19,5.5),.35,steel)
for x in [-14,0,14]: box('Pipe_rack_support',(x,19,2.7),(.5,.6,5.4),edge)

# Thin fissure rays remain underfoot and do not add blockers.
for angle,length in [(0,4.4),(1.8,3.6),(3.3,4.2),(4.6,3.5)]:
    points=[]
    for step in range(5):
        r=.8+length*step/4
        a=angle+random.uniform(-.14,.14)
        points.append(Vector((math.cos(a)*r,math.sin(a)*r,.108)))
    for a,b in zip(points,points[1:]):
        mid=(a+b)/2; delta=b-a
        o=box('Fissure_dark',mid,(delta.length+.1,.16,.01),black)
        o.rotation_euler.z=math.atan2(delta.y,delta.x)
        o=box('Mana_seam',mid+Vector((0,0,.008)),(delta.length,.045,.009),cyan)
        o.rotation_euler.z=math.atan2(delta.y,delta.x)
for i in range(25):
    x=random.choice([-1,1])*random.uniform(15,22); y=random.uniform(-12,16)
    o=box('Edge_scrap',(x,y,.25),(random.uniform(.3,1),random.uniform(.4,1.4),.4),random.choice([steel,rust,concrete[0]]))
    o.rotation_euler.z=random.random()*math.pi

# Portable export: material meshes only, no scripts, no collision, no lights.
bpy.ops.object.select_all(action='DESELECT')
for o in asset_objects: o.select_set(True)
bpy.context.view_layer.objects.active=asset_objects[0]
bpy.ops.export_scene.gltf(filepath=str(EXPORT/'broken_foundry_v1.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)

# Source scene remains unjoined and editable, with a review camera/light.
bpy.ops.object.camera_add(location=(28,-37,32))
camera=bpy.context.object; camera.name='Review_camera'
camera.rotation_euler=(Vector((0,5,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=64
bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(5,-8,25))
bpy.context.object.data.energy=3300;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=25
bpy.ops.object.light_add(type='SUN',location=(0,0,20))
bpy.context.object.rotation_euler=(.4,-.4,-.5);bpy.context.object.data.energy=2
scene=bpy.context.scene
scene.world.color=(.16,.19,.23)
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1344;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ART/'blender-preview.png')
scene.view_settings.view_transform='Standard'
scene['asset_notes']='Broken Foundry v1. Static scenery; open 28m combat square. Blender meters. Godot collision remains owned by main.tscn.'
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'broken_foundry_v1.blend'))
stats={'objects':len(asset_objects),'triangles':sum(len(o.data.polygons) for o in asset_objects)*2,'seed':9062026,'export':'prototype/assets/environment/broken_foundry_v1.glb','note':'Triangle value is a conservative face-times-two estimate; inspect import for exact count.'}
(ART/'asset-manifest.json').write_text(json.dumps(stats,indent=2))
bpy.ops.render.render(write_still=True)
print('FOUNDRY_BUILD_COMPLETE')
