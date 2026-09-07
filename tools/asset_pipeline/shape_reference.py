"""Experimental local Krea Img2Img clay reference; does not replace the original."""
import argparse
import sys
import uuid
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import read_json, write_json, digest, run_lock
from comfy import Comfy

DEFAULT_PROMPT = ('A clean untextured matte neutral gray clay render of the input object. '
    'Preserve its exact silhouette, camera angle, proportions, openings and all component positions. '
    'Soft even studio lighting reveals broad solid surfaces and crisp manufactured edges. '
    'All surfaces use the same smooth gray material. Remove color, painted marks, scratches and reflections. '
    'Plain gray background. No new parts, no text.')

def add_arguments(parser):
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--denoise', type=float, default=0.55)
    parser.add_argument('--prompt', help='Optional complete clay transformation prompt; saved for resume.')
    parser.add_argument('--seed', type=int, help='Default 9062048 for new jobs; resume retains the saved seed.')

def run(args):
    from pipeline import config, HERE
    if not 0.05 <= args.denoise <= 0.85:
        raise ValueError('Denoise must be between .05 and .85.')
    if not args.image.is_file() or args.image.suffix.lower() != '.png':
        raise ValueError('--image must be an existing PNG.')
    if args.seed is not None and not 0 <= args.seed <= 2147483647:
        raise ValueError('Seed must be between 0 and 2147483647.')
    args.out.mkdir(parents=True, exist_ok=True)
    with run_lock(args.out):
        cfg = config()
        client = Comfy(cfg['concept_url'])
        state_file = args.out/'job.json'
        if state_file.exists():
            state = read_json(state_file)
            if state['source_sha256'] != digest(args.image) or state['denoise'] != args.denoise:
                raise ValueError('Use a new output directory for different inputs/settings.')
            graph = read_json(args.out/'api.json')
            if (args.prompt is not None and args.prompt != graph['3']['inputs']['value']) or (args.seed is not None and args.seed != graph['16']['inputs']['seed']):
                raise ValueError('Use a new output directory for different prompt/seed.')
            if state.get('graph_sha256') and digest(args.out/'api.json') != state['graph_sha256']:
                raise ValueError('Saved workflow changed; use a new output directory.')
            if state.get('status') == 'complete':
                if not (args.out/'clay.png').is_file() or (state.get('output_sha256') and digest(args.out/'clay.png') != state['output_sha256']):
                    raise ValueError('Completed clay image is missing or changed; use a new output directory.')
                print('Already complete:', args.out/'clay.png')
                return
        else:
            state = {'token': uuid.uuid4().hex, 'status': 'new', 'source_sha256': digest(args.image), 'denoise': args.denoise}
            graph = read_json(HERE/'templates/concept.json')
            for i in range(1, 6):
                graph[str(i)]['inputs']['value'] = ''
            graph['3']['inputs']['value'] = args.prompt or DEFAULT_PROMPT
            graph['20'] = {'class_type': 'LoadImage', 'inputs': {'image': client.upload(args.image, state['token']+'.png')}}
            graph['21'] = {'class_type': 'VAEEncode', 'inputs': {'pixels': ['20',0], 'vae': ['12',0]}}
            graph.pop('15')
            graph['16']['inputs'].update(latent_image=['21',0], seed=args.seed if args.seed is not None else 9062048, denoise=args.denoise)
            graph['18']['inputs']['filename_prefix'] = 'TelosShapeStudy/'+state['token']+'/clay'
            write_json(args.out/'api.json', graph)
        state['graph_sha256'] = digest(args.out/'api.json')
        save = lambda: write_json(state_file, state)
        save()
        result = client.run(graph, args.out, 'clay', state, save, cfg['timeout_seconds'])
        client.download_image(result, '18', args.out/'clay.png')
        state['status'] = 'complete'
        state['output_sha256'] = digest(args.out/'clay.png')
        save()
        print('Review', args.out/'clay.png', 'before using as --shape-image.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    add_arguments(parser)
    run(parser.parse_args())
