"""Deterministic image preparation, shared sequence transforms and Godot export."""
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def bounds(im):
    if im.mode != 'RGBA':
        raise ValueError('Expected RGBA image')
    a = im.getchannel('A')
    lo, hi = a.getextrema()
    if hi <= 8 or lo == 255:
        raise ValueError('Empty or opaque cutout; review segmentation')
    return a.point(lambda v: 255 if v > 8 else 0).getbbox()

def reference(source, out, size=576):
    if size < 256 or size % 32:
        raise ValueError('Canvas must be >=256 and a multiple of 32')
    out = Path(out)
    out.mkdir(parents=True, exist_ok=False)
    im = Image.open(source).convert('RGBA')
    box = bounds(im)
    crop = im.crop(box)
    scale = min(size*.70/crop.width,size*.72/crop.height)
    resized = crop.resize((round(crop.width*scale),round(crop.height*scale)), Image.Resampling.LANCZOS)
    anchor = (size//2,round(size*.86))
    xy = (anchor[0]-resized.width//2,anchor[1]-resized.height)
    canvas = Image.new('RGBA',(size,size),(180,180,180,255))
    canvas.alpha_composite(resized,xy)
    canvas.convert('RGB').save(out/'reference.png')
    info = {'source':str(Path(source).resolve()),'source_sha256':sha(source),'canvas':[size,size],'source_crop':box,'uniform_scale':scale,'paste':xy,'ground_anchor':anchor,'note':'Default anchor uses visible bottom-center; review actual planted feet. Last-frame references must share this transform.'}
    (out/'reference.json').write_text(json.dumps(info,indent=2)+'\n')
    return info

def sample_indices(count, source_fps, target_fps, start=0, end=None):
    end = count if end is None else end
    if source_fps <= 0 or not 0 < target_fps <= source_fps or not 0 <= start < end <= count:
        raise ValueError('Invalid frame range or cadence')
    # Nearest frame to each output timestamp; no duplicate selection.
    times = np.arange(0,(end-start)/source_fps,1/target_fps)
    return sorted(set(min(end-1,start+round(t*source_fps)) for t in times))

def sequence(images, anchor, target_height, shifts=None, reference_height=None):
    """Apply reviewed translations only; NEVER independently bbox-center frames."""
    if not images or target_height <= 0:
        raise ValueError('Frames and a positive display height required')
    size = images[0].size
    if any(im.size != size for im in images):
        raise ValueError('All frames must share a canvas')
    if not (0 <= anchor[0] <= size[0] and 0 <= anchor[1] <= size[1]):
        raise ValueError('Ground anchor is outside source canvas')
    shifts = shifts or [[0,0] for _ in images]
    if len(shifts) != len(images):
        raise ValueError('One reviewed translation required per sampled frame')
    boxes = [bounds(im) for im in images]
    boxes = [(b[0]+d[0],b[1]+d[1],b[2]+d[0],b[3]+d[1]) for b,d in zip(boxes,shifts)]
    union = [min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes)]
    padding = 4
    union = [min(union[0],anchor[0])-padding,min(union[1],anchor[1])-padding,max(union[2],anchor[0])+padding,max(union[3],anchor[1])+padding]
    union = [math.floor(v) if i<2 else math.ceil(v) for i,v in enumerate(union)]
    if reference_height is not None and (not math.isfinite(reference_height) or reference_height <= 0):
        raise ValueError('Reference height must be finite and positive')
    scale = target_height/(reference_height if reference_height is not None else max(b[3] for b in boxes)-min(b[1] for b in boxes))
    # Keep high resolution PNGs; recommended Godot scale stays separate.
    result=[]
    for im,d in zip(images,shifts):
        cell=Image.new('RGBA',(union[2]-union[0],union[3]-union[1]))
        cell.alpha_composite(im,(round(d[0]-union[0]),round(d[1]-union[1])))
        result.append(cell)
    metrics=[]
    for i,im in enumerate(result):
        a=np.asarray(im.getchannel('A'),dtype=np.float32)/255
        prev=np.asarray(result[max(0,i-1)].getchannel('A'),dtype=np.float32)/255
        metrics.append({'frame':i,'bbox':im.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox(),'alpha_area':float(a.sum()),'alpha_change_from_previous':float(np.abs(a-prev).mean())})
    first=np.asarray(result[0],dtype=np.float32)/255
    last=np.asarray(result[-1],dtype=np.float32)/255
    loop_error=float(np.abs(first[:,:,:3]*first[:,:,3:] - last[:,:,:3]*last[:,:,3:]).mean())
    return result,{'union_crop':union,'ground_anchor':[anchor[0]-union[0],anchor[1]-union[1]],'recommended_scale':scale,'cell_size':result[0].size,'loop_premultiplied_rgb_difference':loop_error,'frame_metrics':metrics,'review_required':True,'note':'Metrics flag candidates for review, not proof of good motion. No automatic temporal mask smoothing or loop crossfade.'}

def export(images, out, info, fps, motion, loop):
    out=Path(out)
    dest=out/'godot'
    dest.mkdir(exist_ok=True)
    w,h=images[0].size
    cols=min(8,max(1,4096//w),len(images))
    rows=math.ceil(len(images)/cols)
    if rows*h>8192 or cols*w>8192:
        raise ValueError('Atlas exceeds 8192px; reduce source canvas or select fewer frames')
    atlas=Image.new('RGBA',(cols*w,rows*h))
    for i,im in enumerate(images):
        atlas.alpha_composite(im,((i%cols)*w,(i//cols)*h))
    atlas.save(dest/'atlas.png')
    lines=['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%(len(images)+2),'','[ext_resource type="Texture2D" path="atlas.png" id="1"]','']
    for i in range(len(images)):
        lines.extend([f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%cols*w}, {i//cols*h}, {w}, {h})',''])
    durations=[1.0]*len(images)
    durations[-1]=info.get('last_frame_duration_multiplier',1.0)
    entries=',\n'.join('{"duration": %s, "texture": SubResource("Frame_%d")}'%(durations[i],i) for i in range(len(images)))
    lines.extend(['[resource]','animations = [{"frames": ['+entries+'], "loop": '+str(loop).lower()+', "name": &"'+motion+'", "speed": '+str(float(fps))+'}]'])
    (dest/'animation.tres').write_text('\n'.join(lines)+'\n')
    ax,ay=info['ground_anchor']
    s=info['recommended_scale']
    scene=f'''[gd_scene load_steps=2 format=3]
[ext_resource type="SpriteFrames" path="animation.tres" id="1"]
[node name="AnimationVisual" type="Node2D"]
[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 2
position = Vector2({(w/2-ax)*s}, {(h/2-ay)*s})
scale = Vector2({s}, {s})
sprite_frames = ExtResource("1")
animation = &"{motion}"
autoplay = "{motion}"
'''
    (dest/'visual.tscn').write_text(scene)
    (dest/'manifest.json').write_text(json.dumps(info,indent=2)+'\n')
    # GIF is a review only; atlas preserves full RGBA without palette reduction.
    preview=[]
    for im in images:
        canvas=Image.new('RGBA',im.size,'#29333a')
        canvas.alpha_composite(im)
        canvas.thumbnail((320,320))
        preview.append(canvas.convert('RGB'))
    preview[0].save(out/'preview.gif',save_all=True,append_images=preview[1:],duration=[round(1000*d/fps) for d in durations],**({'loop':0} if loop else {}))
    sheet=Image.new('RGB',(800,math.ceil(min(16,len(images))/4)*224),'#29333a')
    for j,i in enumerate(np.linspace(0,len(images)-1,min(16,len(images))).astype(int)):
        thumb=images[i].copy(); thumb.thumbnail((192,192))
        x,y=j%4*200,j//4*224
        sheet.paste(thumb,(x,y),thumb)
        ImageDraw.Draw(sheet).text((x+4,y+200),f'frame {i}',fill='white')
    sheet.save(out/'contact-sheet.png')
