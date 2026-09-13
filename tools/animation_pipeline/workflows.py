"""Flat, editable native/API ComfyUI graphs for the installed local H3 stack."""
import copy
import json
import math

COMMON = ('Locked-off side-view game animation of the single reference creature facing right. '
          'Preserve its shell pattern, anatomy, silhouette, colors, scale and screen position. '
          'Uniform neutral background and constant lighting. Entire body and claws stay inside the canvas. '
          'No body rotation, camera movement, zoom, cuts, new limbs, particles, changing shadows or other objects. ')
MOTIONS = {
    'idle': 'Feet remain planted on the same ground line; the torso subtly breathes and the forward claw slowly flexes once, then returns to the original resting pose. One gentle complete cycle over the clip, smooth movement across the loop boundary. No walking or foot shuffling. No music or dialogue.',
    'walk': 'One complete slow in-place walking stride, with alternating planted feet, clear weight transfer and small natural torso motion. Body stays centered with no net forward travel. Return to the initial stride phase by the end with continuous cyclic motion. No attack or claw strike. No music or dialogue.',
    'attack': 'One attack only. First quarter: deliberate anticipation, raising the forward claw. Middle: a distinct forward/downward claw strike. Final half: settle and recover to the original resting pose. Feet remain planted; no walking or extra strikes. No impact particles or target objects. No music or dialogue.',
}

def frame_count(seconds):
    frames = max(5, round(seconds * 24))
    return frames + (5 - frames % 17) % 17

def node(kind, **inputs):
    return {'class_type': kind, 'inputs': inputs}

def graph(motion, first, last=None, size=576, seconds=3, seed=234508078907053, prefix='Telos/Animation'):
    return {
        '1': node('LoadImage', image=first),
        '2': node('LoadImage', image=last or first),
        '3': node('UNETLoader', unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors', weight_dtype='default'),
        '4': node('CLIPLoader', clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors', type='minimax', device='default'),
        '5': node('VAELoader', vae_name='minimax_h3_video_vae_fp16.safetensors'),
        '6': node('VAELoader', vae_name='minimax_h3_audio_vae_fp32.safetensors'),
        '7': node('MiniMaxH3ImageToVideo', clip=['4',0], vae=['5',0], first_frame=['1',0], last_frame=['2',0], prompt=COMMON+MOTIONS[motion], width=size, height=size, length=frame_count(seconds)),
        '8': node('RandomNoise', noise_seed=seed),
        '9': node('KSamplerSelect', sampler_name='res_multistep'),
        '10': node('BasicScheduler', model=['3',0], scheduler='simple', steps=15, denoise=1.0),
        '11': node('BasicGuider', model=['3',0], conditioning=['7',0]),
        '12': node('SamplerCustomAdvanced', noise=['8',0], guider=['11',0], sampler=['9',0], sigmas=['10',0], latent_image=['7',1]),
        '13': node('VAEDecode', samples=['12',0], vae=['5',0]),
        '14': node('VAEDecodeAudio', samples=['12',0], vae=['6',0]),
        '15': node('CreateVideo', images=['13',0], audio=['14',0], fps=24.0, bit_depth=8),
        '16': node('SaveVideo', video=['15',0], filename_prefix=prefix+'/'+motion+'/preview', format='mp4', codec='auto'),
        '17': node('SaveImage', images=['13',0], filename_prefix=prefix+'/'+motion+'/master'),
    }

def cutout(image, prefix):
    return {
        '1': node('LoadImage', image=image),
        '2': node('Trellis2RemoveBackground', image=['1',0], low_vram=True),
        '3': node('InvertMask', mask=['2',1]),
        '4': node('JoinImageWithAlpha', image=['1',0], alpha=['3',0]),
        '5': node('SaveImage', images=['4',0], filename_prefix=prefix),
    }

def native(api, schemas, title):
    """Build native link and widget values from installed schemas, no subgraph bindings."""
    nodes, links = [], []
    for order, (key, entry) in enumerate(api.items()):
        schema = schemas[entry['class_type']]
        fields = {**schema['input'].get('required', {}), **schema['input'].get('optional', {})}
        n = {'id': int(key), 'type': entry['class_type'], 'title': entry['class_type'], 'pos': [(order//4)*440,(order%4)*330], 'size': [410,300], 'flags': {}, 'order': order, 'mode': 0, 'inputs': [], 'outputs': [{'name': name, 'type': typ, 'links': []} for name, typ in zip(schema['output_name'],schema['output'])], 'properties': {'Node name for S&R': entry['class_type']}, 'widgets_values': []}
        for name in fields:
            if name not in entry['inputs']:
                continue
            value = entry['inputs'][name]
            if isinstance(value, list):
                typ = schemas[api[value[0]]['class_type']]['output'][value[1]]
                ident = len(links)+1
                links.append([ident,int(value[0]),value[1],int(key),len(n['inputs']),typ])
                n['inputs'].append({'name':name,'type':typ,'link':ident})
            else:
                n['widgets_values'].append(value)
                if name == 'noise_seed':
                    n['widgets_values'].append('fixed')
        if entry['class_type'] == 'LoadImage':
            n['widgets_values'].append('image')
        if entry['class_type'] == 'MiniMaxH3ImageToVideo':
            n['size'] = [410, 510]
        nodes.append(n)
    for column in range((len(nodes)+3)//4):
        y=0
        for n in nodes[column*4:column*4+4]:
            n['pos'][1]=y
            y+=n['size'][1]+50
    by_id = {n['id']:n for n in nodes}
    for ident, source, slot, *_ in links:
        by_id[source]['outputs'][slot]['links'].append(ident)
    notes = ('TELOS '+title+'\nFirst/last are prepared references with identical canvas/scale. Same image is a loop/recovery constraint, not proof of a seamless cycle. Change both selectors for a different actor. Width/height and supported frame count are on H3 node; defaults 576 square, 73 frames at 24 fps. Seed is fixed. SaveImage exports ALL decoded frames as lossless PNG masters; SaveVideo is preview/audio only. Use animation.ps1 package for frame selection, per-frame cutout, ONE union crop/pivot, QC and Godot export. Review alpha/loop artifacts before game use. Damage events belong to the simulation. No live game changes.')
    nodes.append({'id':99,'type':'MarkdownNote','title':'READ FIRST — '+title,'pos':[-470,0],'size':[440,560],'flags':{},'order':len(nodes),'mode':0,'inputs':[],'outputs':[],'properties':{},'widgets_values':[notes]})
    return {'version':0.4,'last_node_id':99,'last_link_id':len(links),'nodes':nodes,'links':links,'groups':[],'config':{},'extra':{'Telos':{'motion':title}}}
