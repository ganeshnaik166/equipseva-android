"""Create every campus/robot mesh in Blender; export editable source, GLB and poster.
Run: blender -b --python scripts/build_hq_scene.py -- <output-directory>
Animations are illustrative work loops, never project telemetry or gate evidence.
"""
import bpy
import math
import sys
import os
import json
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else os.path.join(ROOT, 'website', 'progress-assets')
os.makedirs(OUT, exist_ok=True)
SOURCE = os.path.join(ROOT, 'design', 'blender')
os.makedirs(SOURCE, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
CURRENT = None

def material(name, color, metal=0, rough=.5, emission=0):
    color = color.lstrip('#')
    rgb = [int(color[i:i+2], 16) / 255 for i in (0,2,4)]
    rgb = [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = rough
    shader.inputs['Emission Color'].default_value = (*rgb, 1)
    shader.inputs['Emission Strength'].default_value = emission
    return m

M = {
 'ground':material('Warm mineral ground','#dae3db'),
 'pad':material('Ivory porcelain','#f5f2e9'),
 'white':material('Robot ceramic','#ffffff', .12,.32),
 'dark':material('Graphite hardware','#18353d',.2,.42),
 'glass':material('Deep teal glazing','#205c65',.5,.22),
 'teal':material('EquipSeva teal','#19c5ba',.2,.36),
 'mint':material('Mint signal','#a8f0cf',0,.4,.3),
 'blue':material('Engineer blue','#8dbbe8',.12,.45),
 'purple':material('Planning lilac','#bba6e2',.12,.48),
 'gold':material('Warm amber','#efb35e',.16,.4),
 'coral':material('Release hold','#e18774',.12,.5),
 'light':material('Screen light','#c9fff2',0,.25,1),
 'road':material('Circuit paths','#96b6ae'),
 'green':material('Plant green','#5c9983'),
}

def finish(obj, name, mat):
    obj.name = name
    if CURRENT is not None: obj.parent = CURRENT
    if mat: obj.data.materials.append(mat)
    return obj

def box(name, loc, size, mat, bevel=.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = finish(bpy.context.object,name,mat)
    o.scale = size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons: p.use_smooth=True
    mod=o.modifiers.new('Weighted surfaces','WEIGHTED_NORMAL')
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def cylinder(name,loc,radius,depth,mat,vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=finish(bpy.context.object,name,mat)
    bevel=o.modifiers.new('Edge bevel','BEVEL');bevel.width=min(.04,depth*.15);bevel.segments=2
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
    for p in o.data.polygons:p.use_smooth=True
    return o

def sphere(name,loc,size,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=loc)
    o=finish(bpy.context.object,name,mat);o.scale=size
    for p in o.data.polygons:p.use_smooth=True
    return o

def beam(name,start,end,radius,mat):
    a,b=Vector(start),Vector(end)
    o=cylinder(name,(a+b)/2,radius,(b-a).length,mat,12)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def text(name,body,loc,size,mat,rotate=(math.pi/2,0,0)):
    curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.size=size;curve.align_x='CENTER';curve.extrude=.007;curve.bevel_depth=.001
    o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=rotate
    finish(o,name,mat)
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
    return o

def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent
    return o

def robot(name, loc, accent, phase=0, scale=1):
    global CURRENT
    group=empty(name,loc,CURRENT);old=CURRENT;CURRENT=group;group.scale=(scale,)*3
    box(name+'_hoverbase',(0,0,.18),(.53,.4,.12),M['dark'])
    box(name+'_body',(0,0,.52),(.5,.4,.52),M['white'],.15)
    box(name+'_badge',(0,-.212,.58),(.16,.025,.1),accent,.015)
    head=empty(name+'_head',(0,0,.99),group);CURRENT=head
    box(name+'_head_shell',(0,0,0),(.68,.49,.43),M['white'],.15)
    box(name+'_visor',(0,-.235,-.01),(.54,.07,.25),M['dark'],.09)
    for x in [-.14,.14]:sphere(name+'_eye',(x,-.283,.02),(.042,.019,.055),M['light'])
    box(name+'_smile',(0,-.281,-.073),(.13,.018,.024),accent,.01)
    beam(name+'_antenna',(0,0,.2),(0,0,.37),.023,M['dark'])
    sphere(name+'_signal',(0,0,.39),(.055,)*3,accent)
    for frame,angle in [(1,-.12),(31,.12),(61,-.12),(91,.12),(121,-.12)]:
        head.rotation_euler.z=angle;head.keyframe_insert(data_path='rotation_euler',frame=frame)
    CURRENT=group
    for side in [-1,1]:
        arm=empty(name+('_left_arm' if side<0 else '_right_arm'),(side*.31,0,.72),group);CURRENT=arm
        beam(name+'_forearm',(0,0,0),(side*.06,-.17,-.2),.07,M['white'])
        sphere(name+'_hand',(side*.06,-.19,-.21),(.09,)*3,accent)
        for frame,a in [(1,0),(16,.22),(31,0),(46,.22),(61,0),(76,.22),(91,0),(106,.22),(121,0)]:
            arm.rotation_euler.x=a*side;arm.keyframe_insert(data_path='rotation_euler',frame=frame)
    CURRENT=old
    base_z=loc[2]
    for frame,dz in [(1,0),(31,.09),(61,0),(91,.09),(121,0)]:
        group.location.z=base_z+dz;group.keyframe_insert(data_path='location',frame=frame)
    return group

def desk(name,loc,accent):
    x,y,z=loc
    box(name+'_top',(x,y,z),(.95,.62,.12),M['white'])
    box(name+'_leg',(x,y,z-.28),(.13,.13,.5),M['dark'],.025)
    screen=box(name+'_monitor',(x,y+.12,z+.29),(.67,.09,.4),M['dark'],.045)
    box(name+'_screen',(x,y+.065,z+.3),(.55,.018,.29),accent,.025)
    for i in range(3):box(name+'_code_'+str(i),(x-.08,y+.046,z+.22+i*.07),(.28+i*.045,.01,.018),M['light'],.004)
    box(name+'_keyboard',(x,y-.12,z+.08),(.51,.21,.025),M['dark'],.01)

def plant(name,loc):
    x,y,z=loc
    cylinder(name+'_pot',(x,y,z+.16),.14,.26,M['white'])
    for dx,dy,dz in [(0,0,.42),(.08,0,.35),(-.08,.04,.34)]:sphere(name+'_leaf',(x+dx,y+dy,z+dz),(.12,.09,.22),M['green'])

OFFICES = [
 ('login','LOGIN',(-7,5),'teal'),('hospital','HOSPITAL',(0,8.5),'blue'),
 ('engineer','ENGINEER',(7,5),'gold'),('admin','ADMIN',(8,-2.5),'purple'),
 ('qa','QA LAB',(4,-8),'blue'),('security','SECURITY',(-3.5,-8),'teal'),
 ('plan','NEXT PLAN',(-8,-2.5),'purple'),
]

# The campus sits on a chamfered miniature-world plinth.
box('Campus plinth',(0,-.8,-.36),(24,23,.5),M['ground'],.8)
box('Campus lower edge',(0,-.8,-.64),(23.3,22.3,.24),M['pad'],.6)
for x in range(-10,11,2):
    for y in range(-10,10,2):cylinder('Ground marker',(x,y,-.087),.022,.01,M['road'],8)

for key,label,(x,y),color in OFFICES:
    distance=math.hypot(x,y);ux,uy=x/distance,y/distance
    beam('Spoke_'+key,(ux*1.8,uy*1.8,-.02),(x-ux*1.7,y-uy*1.7,-.02),.08,M['road'])
    for d in [2.4,3.2,4.0,4.8]:
        if d<distance-1.8:box('Signal_'+key,(ux*d,uy*d,.035),(.16,.16,.045),M['mint'],.02)
    root=empty('HQ_'+key,(x,y,0));root['hq']=key;CURRENT=root
    accent=M[color]
    box(key+'_foundation',(0,0,.11),(3.5,3.1,.24),M['pad'],.22)
    box(key+'_accent',(0,0,.265),(3.2,2.8,.1),accent,.14)
    box(key+'_floor',(0,-.03,.37),(3.02,2.65,.16),M['white'],.13)
    box(key+'_backwall',(0,1.12,1.15),(2.95,.15,1.5),M['pad'])
    box(key+'_fascia',(0,1.03,1.74),(2.92,.17,.24),accent)
    box(key+'_window',(.5,1.015,1.2),(1.48,.045,.7),M['glass'])
    for dx in [-.15,.35,.85]:box(key+'_windowframe',(dx,.984,1.2),(.035,.025,.66),M['white'],.005)
    box(key+'_sidewall',(-1.4,.55,.83),(.13,1.2,.78),accent)
    box(key+'_plaque',(0,-1.37,.47),(2.3,.12,.36),M['dark'],.045)
    text(key+'_label',label,(0,-1.438,.39),.19,M['white'])
    desk(key+'_desk',(.55,.12,1.02),accent)
    robot('Bot_'+key,(.5,-.73,.5),accent)
    plant(key+'_plant',(-1, .72,.46))
    if key=='hospital':
        box('Hospital cross upright',(-.82,.985,1.33),(.13,.07,.6),M['teal'],.015)
        box('Hospital cross horizontal',(-.82,.945,1.33),(.5,.08,.13),M['teal'],.015)
        box('Hospital diagnostic bed',(-.78,-.25,.77),(.74,1.15,.24),M['blue'])
        box('Hospital pillow',(-.78,.1,.92),(.61,.29,.14),M['white'])
    elif key=='engineer':
        box('Engineer instrument',(-.75,-.25,.83),(.7,.72,.72),M['dark'])
        cylinder('Engineer dial',(-.75,-.25,1.22),.23,.06,M['gold'])
        beam('Engineer calibration tool',(-1,-.7,.53),(-.5,-.7,.53),.045,M['gold'])
    elif key=='admin':
        for i,h in enumerate([.4,.75,1.05]):box('Admin chart '+str(i),(-1+i*.32,.2,.47+h/2),(.21,.28,h),[M['blue'],M['teal'],M['purple']][i],.04)
    elif key=='login':
        box('Login portal left',(-1,-.2,1.02),(.16,.27,1.1),accent)
        box('Login portal right',(-.3,-.2,1.02),(.16,.27,1.1),accent)
        box('Login portal crown',(-.65,-.2,1.57),(.86,.27,.18),accent)
        cylinder('Login key token',(-.65,-.23,.95),.19,.08,M['gold'])
    elif key=='security':
        shield=box('Security shield',(-.78,.32,1.05),(.67,.18,.87),M['teal'],.2)
        shield.rotation_euler.y=-.12
        box('Security lock',(-.78,.18,1.06),(.27,.08,.24),M['light'],.045)
        text('Security guard note','CHECK',(-.78,-.01,.6),.13,M['dark'])
    elif key=='qa':
        box('QA test bench',(-.85,-.05,.86),(.77,.84,.13),M['dark'])
        for i,mat in enumerate([M['blue'],M['gold'],M['white']]):box('QA fixture '+str(i),(-1.08+i*.23,-.05,1.01),(.16,.29,.2),mat,.035)
    else:
        for i,mat in enumerate([M['purple'],M['blue'],M['gold']]):box('Planning stack '+str(i),(-.8,-.2,.53+i*.15),(.78,.85,.13),mat,.04)
        box('Planning board',(-.86,.7,1.17),(.75,.09,.71),M['white'])
        for dx,dz in [(-.14,.12),(.14,.12),(-.14,-.12),(.14,-.12)]:box('Planning card',(-.86+dx,.636,1.17+dz),(.2,.022,.15),M['gold'],.015)
    # Click/label anchor is exported with the complete branch transform.
    anchor=empty('Anchor_'+key,(0,0,2.05),root);anchor['hq']=key
    CURRENT=None

# Central EquipSeva hub, using the real project logo as a baked glTF texture.
CURRENT=empty('HQ_center');CURRENT['hq']='center'
cylinder('Center ring',(0,0,.12),2.05,.26,M['teal'],64)
cylinder('Center porcelain',(0,0,.32),1.83,.19,M['white'],64)
cylinder('Center dark level',(0,0,.62),1.3,.42,M['dark'],48)
cylinder('Center mint trim',(0,0,.87),1.33,.09,M['mint'],48)
box('Central logo pedestal',(0,.2,1.65),(2.05,1.6,1.7),M['white'],.24)
logo_material=bpy.data.materials.new('Original EquipSeva logo');logo_material.use_nodes=True
nodes=logo_material.node_tree.nodes;shader=nodes.get('Principled BSDF')
image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(os.path.join(SOURCE,'equipsevalogo.png'));image.image.pack()
logo_material.node_tree.links.new(image.outputs['Color'],shader.inputs['Base Color'])
shader.inputs['Roughness'].default_value=.4
bpy.ops.mesh.primitive_plane_add(size=1,location=(0,-.61,1.65),rotation=(math.pi/2,0,0))
logo=finish(bpy.context.object,'EquipSeva logo',logo_material);logo.scale=(1.55,1.55,1)
text('EquipSeva wordmark','EQUIPSEVA',(0,-1.325,.61),.28,M['white'])
robot('Bot_coordinator',(-1.1,-.5,.87),M['teal'],scale=.55)
empty('Anchor_center',(0,0,3),CURRENT)
CURRENT=None

# Output belt: three deliberately closed checkpoints, not decorative pass claims.
box('Release lane',(1.75,-11,.03),(16,1.6,.22),M['dark'],.25)
for x in [-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8]:
    r=cylinder('Conveyor roller',(x,-11,.2),.07,1.15,M['road'],12);r.rotation_euler.x=math.pi/2
for key,x,color in [('security_gate',-3.5,'teal'),('qa_gate',1.5,'blue'),('main',7,'purple')]:
    root=empty('HQ_'+key,(x,-11,0));root['hq']=key;CURRENT=root
    box(key+'_left',(-.69,0,.96),(.16,.25,1.45),M['white'])
    box(key+'_right',(.69,0,.96),(.16,.25,1.45),M['white'])
    box(key+'_header',(0,0,1.72),(1.6,.36,.3),M[color])
    box(key+'_closed_bar',(0,-.08,.97),(1.37,.17,.18),M['coral'],.02)
    text(key+'_title',{'security_gate':'SECURITY','qa_gate':'QA CHECK','main':'MAIN'}[key],(0,-.2,1.65),.14,M['dark'])
    empty('Anchor_'+key,(0,0,2.03),root)
    CURRENT=None
box('Candidate crate',(-5.9,-11,.58),(.65,.65,.65),M['gold'],.11)
box('Candidate seal',(-5.9,-11,.925),(.18,.65,.03),M['white'],.01)
text('Output label','RELEASE LANE  /  AWAITING CHECKS',(1.5,-11.82,.02),.21,M['dark'],(0,0,0))

# Merge static meshes sharing parent/material, preserving animated robot groups
# and each office root. This reduces WebGL draw calls without baking work loops.
groups={}
for o in list(bpy.data.objects):
    if o.type=='MESH' and not o.animation_data and len(o.data.materials)==1:
        groups.setdefault((o.parent,o.data.materials[0]),[]).append(o)
for objects in groups.values():
    if len(objects)>1:
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()

# Blender scene, source and poster.
scene=bpy.context.scene
scene.frame_start=1;scene.frame_end=121;scene.render.fps=30;scene.frame_set(1)
scene.world.color=(.8,.8,.8)
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.58,.69,.65,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for name,loc,energy,size in [('Large softbox',(-8,-10,18),2300,12),('Rim softbox',(10,5,13),1800,10)]:
    bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.name=name;light.data.energy=energy;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(20,-27,29))
camera=bpy.context.object;camera.rotation_euler=(Vector((0,-1,0))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=32;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
# Prefer CUDA if the host provides it, otherwise retain CPU rendering.
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='CUDA';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='CUDA'
    if any(d.type=='CUDA' for d in prefs.devices):scene.cycles.device='GPU'
except Exception:pass
scene.render.resolution_x=1500;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX';scene.render.filepath=os.path.join(SOURCE,'hq-poster.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,'equipseva-headquarters.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'equipseva-headquarters.glb'),export_format='GLB',export_extras=True,export_animations=True,export_cameras=False,export_lights=False)
metadata={'generator':'Blender '+bpy.app.version_string,'offices':[dict(id=k,label=l,position=[xy[0],0,-xy[1]]) for k,l,xy,c in OFFICES], 'source':'scripts/build_hq_scene.py','frames':121,'fps':30,'animationMeaning':'Illustrative loops, not live telemetry or release approval','objects':len(bpy.data.objects)}
with open(os.path.join(OUT,'scene-manifest.json'),'w') as f:json.dump(metadata,f,indent=2)
bpy.ops.render.render(write_still=True)
print('HQ_SCENE_COMPLETE',OUT)
