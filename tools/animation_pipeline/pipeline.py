"""Local H3 generation and reproducible sprite preparation. No live game edits."""
import argparse
import json
import math
import sys
import uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'asset_pipeline'))
import requests
from PIL import Image
import av
from common import ROOT, read_json, write_json
from comfy import Comfy
from workflows import graph, cutout, native, MOTIONS
from prepare import reference, sha, sample_indices, sequence, export

WORKFLOWS=ROOT/'art/side-view/animations/workflows'

def client():
    return Comfy(read_json(ROOT/'tools/asset_pipeline/config.json')['concept_url'])

def local(path):
    result=Path(path).resolve()
    if not result.is_relative_to(ROOT):
        raise ValueError('Output must stay inside this repository')
    return result

def immutable(path,data):
    if path.exists():
        if read_json(path)!=data:
            raise ValueError('Settings/source changed: use a new output folder: '+str(path))
    else:
        write_json(path,data)

def job(c,api,out):
    out.mkdir(parents=True,exist_ok=True)
    immutable(out/'api.json',api)
    record=read_json(out/'job.json') if (out/'job.json').exists() else {'token':uuid.uuid4().hex}
    write_json(out/'job.json',record)
    if record.get('status')=='complete':
        return read_json(out/'history.json')
    if record.get('status')=='failed':
        raise RuntimeError('Saved job failed; inspect logs and use a new run after fixing it')
    result=c.run(api,out,'render',record,lambda:write_json(out/'job.json',record),3600)
    write_json(out/'history.json',result)
    record['status']='complete';write_json(out/'job.json',record)
    return result

def uploaded(c,path,out):
    out.mkdir(parents=True,exist_ok=True)
    record=out/'upload.json'
    h=sha(path)
    if record.exists():
        data=read_json(record)
        if data['sha256']!=h:
            raise ValueError('Uploaded source changed; use a new run')
        return data['name']
    name=c.upload(path,'telos_animation_'+uuid.uuid4().hex+'.png')
    write_json(record,{'name':name,'sha256':h})
    return name

def build(args):
    c=client(); schemas=c.get('/object_info')
    WORKFLOWS.mkdir(parents=True,exist_ok=True)
    first=uploaded(c,Path(args.reference),WORKFLOWS/'reference-upload')
    im=Image.open(args.reference)
    if im.width!=im.height or im.width%32:
        raise ValueError('Use the square, multiple-of-32 prepared reference')
    for i,motion in enumerate(MOTIONS,1):
        api=graph(motion,first,size=im.width)
        c.validate(api)
        write_json(WORKFLOWS/f'0{i}_{motion}.api.json',api)
        write_json(WORKFLOWS/f'0{i}_{motion}.json',native(api,schemas,motion))
    api=cutout(first,'Telos/Animation/mask-review')
    c.validate(api)
    write_json(WORKFLOWS/'04_frame_cutout.api.json',api)
    write_json(WORKFLOWS/'04_frame_cutout.json',native(api,schemas,'frame cutout — one frame only'))
    print('Built four native/API pairs:',WORKFLOWS)

def run(args):
    out=local(args.out);out.mkdir(parents=True,exist_ok=True)
    im=Image.open(args.reference)
    if im.width!=im.height or im.width%32:
        raise ValueError('Reference must be square, multiple of 32; use reference command')
    last=args.last or args.reference
    if Image.open(last).size!=im.size:
        raise ValueError('First and last reference must share dimensions and ground anchor')
    spec={'motion':args.motion,'reference_sha256':sha(args.reference),'last_sha256':sha(last),'seed':args.seed,'seconds':args.seconds,'size':im.width}
    immutable(out/'spec.json',spec)
    c=client()
    first_name=uploaded(c,Path(args.reference),out/'first-upload')
    last_name=first_name if sha(last)==sha(args.reference) else uploaded(c,Path(last),out/'last-upload')
    api=graph(args.motion,first_name,last_name,im.width,args.seconds,args.seed,'Telos/Animation/'+out.name)
    result=job(c,api,out/'generation')
    masters=out/'masters';masters.mkdir(exist_ok=True)
    outputs=result.get('outputs',{}).get('17',{}).get('images',[])
    if len(outputs)!=api['7']['inputs']['length']:
        raise ValueError('Unexpected decoded frame count; inspect generation/history.json')
    rows=[]
    for i,item in enumerate(outputs):
        path=masters/f'frame_{i:04d}.png'
        r=requests.get(c.url+'/view',params=item,timeout=60);r.raise_for_status()
        if path.exists() and path.read_bytes()!=r.content:
            raise ValueError('Master was edited; use a new run')
        path.write_bytes(r.content)
        rows.append({'file':path.name,'sha256':sha(path),'time':i/24})
    write_json(out/'masters.json',{'fps':24,'frames':rows,'server_preview':result.get('outputs',{}).get('16',{})})
    print('Lossless masters:',masters,flush=True)
    if args.to=='package':
        reference_info=Path(args.reference).with_name('reference.json')
        if not reference_info.exists():
            raise ValueError('Automatic package requires prepared reference.json; use package with explicit --anchor for other references')
        a=argparse.Namespace(source=str(masters),out=str(out/'package'),source_fps=24.0,fps=12.0,start=0,end=None,anchor=read_json(reference_info)['ground_anchor'],height=args.height,motion=args.motion,loop=args.motion!='attack',shifts=None)
        package(a)

def sources(args,out):
    source=Path(args.source)
    if source.is_dir():
        paths=sorted(source.glob('*.png'))
        if not paths:
            raise ValueError('No PNG masters in source directory')
        return paths,args.source_fps
    dest=out/'decoded';dest.mkdir(exist_ok=True)
    paths=[];times=[]
    with av.open(str(source)) as video:
        stream=video.streams.video[0];fps=float(stream.average_rate)
        for i,frame in enumerate(video.decode(stream)):
            path=dest/f'frame_{i:04d}.png'
            frame.to_image().save(path)
            paths.append(path);times.append(float(frame.time))
    if any(abs((b-a)-1/fps)>1e-3 for a,b in zip(times,times[1:])):
        raise ValueError('Variable-rate video: normalize cadence explicitly before packaging')
    return paths,fps

def package(args):
    out=local(args.out);out.mkdir(parents=True,exist_ok=True)
    source=Path(args.source)
    source_hash=sha(source) if source.is_file() else [{'name':p.name,'sha256':sha(p)} for p in sorted(source.glob('*.png'))]
    shifts=read_json(args.shifts) if args.shifts else None
    reference_height=getattr(args,'reference_height',None)
    masks=Path(args.masks) if getattr(args,'masks',None) else None
    spec={'source':str(source.resolve()),'source_hash':source_hash,'source_fps':args.source_fps,'fps':args.fps,'start':args.start,'end':args.end,'anchor':args.anchor,'height':args.height,'motion':args.motion,'loop':args.loop,'shifts':shifts}
    if reference_height is not None:
        spec['reference_height']=reference_height
    if masks:
        spec['reviewed_masks']=[{'name':p.name,'sha256':sha(p)} for p in sorted(masks.glob('*.png'))]
    immutable(out/'spec.json',spec)
    if (out/'complete.json').exists():
        complete=read_json(out/'complete.json')
        for name,h in complete['outputs'].items():
            if not (out/name).exists() or sha(out/name)!=h:
                raise ValueError('Completed output missing/edited: '+name)
        print('Verified completed package:',out);return
    paths,source_fps=sources(args,out)
    indices=sample_indices(len(paths),source_fps,args.fps,args.start,args.end)
    c=client();images=[]
    for n,index in enumerate(indices):
        if masks:
            images.append(Image.open(masks/f'frame_{index:04d}.png').convert('RGBA'))
            continue
        folder=out/'masks'/f'{index:04d}';folder.mkdir(parents=True,exist_ok=True)
        target=folder/'rgba.png';receipt=folder/'output.json'
        if receipt.exists():
            if sha(target)!=read_json(receipt)['sha256']:
                raise ValueError('Mask output edited; use a new package to preserve provenance')
        else:
            image_name=uploaded(c,paths[index],folder/'upload')
            api=cutout(image_name,'Telos/Animation/masks/'+out.name+f'/{index:04d}')
            result=job(c,api,folder/'job')
            c.download_image(result,'5',target)
            write_json(receipt,{'sha256':sha(target)})
        images.append(Image.open(target).convert('RGBA'))
        print(f'Mask {n+1}/{len(indices)} (source frame {index})',flush=True)
    frames,info=sequence(images,args.anchor,args.height,shifts,reference_height)
    info['reference_height']=reference_height
    info['scale_basis']='shared_reference' if reference_height is not None else 'clip_bounds_preview_only'
    info.update(source_indices=indices,source_fps=source_fps,playback_fps=args.fps,motion=args.motion,loop_requested=args.loop,damage_event=None)
    # Preserve requested clip end exactly, including a shorter final sampled frame.
    end=len(paths) if args.end is None else args.end
    info['last_frame_duration_multiplier']=((end-args.start)/source_fps-(len(indices)-1)/args.fps)*args.fps
    info['warnings']=[]
    if info['loop_premultiplied_rgb_difference']>.025 and args.loop:
        info['warnings'].append('First/last mismatch: inspect loop; looping is requested, not artistically validated')
    metrics=info['frame_metrics']
    for prev,cur in zip(metrics,metrics[1:]):
        if abs(cur['alpha_area']-prev['alpha_area'])/max(prev['alpha_area'],1)>.15:
            info['warnings'].append(f"Frame {cur['frame']}: alpha area changed >15%; inspect motion or mask flicker")
    write_json(out/'review.json',info)
    export(frames,out,info,args.fps,args.motion,args.loop)
    outputs={str(p.relative_to(out)).replace('\\','/'):sha(p) for p in (out/'godot').glob('*') if p.is_file()}
    write_json(out/'complete.json',{'outputs':outputs})
    print('Package ready for REVIEW:',out,'Warnings:',info['warnings'],flush=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='command',required=True)
    r=sub.add_parser('reference');r.add_argument('--image',required=True);r.add_argument('--out',required=True);r.add_argument('--size',type=int,default=576)
    b=sub.add_parser('build');b.add_argument('--reference',required=True)
    r=sub.add_parser('run');r.add_argument('--reference',required=True);r.add_argument('--last');r.add_argument('--motion',choices=MOTIONS,default='idle');r.add_argument('--out',required=True);r.add_argument('--seconds',type=float,default=3);r.add_argument('--seed',type=int,default=234508078907053);r.add_argument('--height',type=float,default=112);r.add_argument('--to',choices=['generate','package'],default='package')
    r=sub.add_parser('package');r.add_argument('--source',required=True);r.add_argument('--out',required=True);r.add_argument('--source-fps',type=float,default=24);r.add_argument('--fps',type=float,default=12);r.add_argument('--start',type=int,default=0);r.add_argument('--end',type=int);r.add_argument('--anchor',nargs=2,type=float,required=True);r.add_argument('--height',type=float,default=112);r.add_argument('--motion',choices=MOTIONS,default='idle');r.add_argument('--loop',action='store_true');r.add_argument('--shifts')
    r.add_argument('--masks',help='Reviewed full-canvas RGBA files named frame_NNNN.png by source index')
    r.add_argument('--reference-height',type=float,help='Shared source-pixel reference pose height for every clip of this actor')
    a=p.parse_args()
    if a.command=='reference':
        print(reference(a.image,local(a.out),a.size))
    elif a.command=='build':build(a)
    elif a.command=='run':
        if not math.isfinite(a.seconds) or not 0<a.seconds<=15 or not 0<=a.seed<2**64:p.error('seconds must be (0,15], seed uint64')
        run(a)
    else:package(a)

if __name__=='__main__':
    try:main()
    except KeyboardInterrupt:
        print('Stopped waiting. GPU job may continue; repeat the same command to resume.',file=sys.stderr);sys.exit(130)
