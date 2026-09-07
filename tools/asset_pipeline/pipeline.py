"""Local concept -> TRELLIS -> Blender -> Godot asset pipeline."""
import argparse
import json
import shutil
import subprocess
import sys
import uuid
import struct
from urllib.parse import urlparse
from pathlib import Path
from datetime import datetime, timezone
sys.path.insert(0, str(Path(__file__).resolve().parent)) # Windows embedded Python omits script directory.
from common import ROOT, RUNS, read_json, write_json, digest, spec_hash, safe_name, within, run_lock
from comfy import Comfy

HERE = Path(__file__).resolve().parent
STAGES = ('concept', 'mesh', 'prepare', 'import')
DEFAULT_COMPOSITION = 'One isolated object, entire object visible, centered three-quarter view, simple neutral gray background. No scenery, pedestal, text, people or multiple views. Clear silhouette, separated appendages, even studio lighting. Design a single reusable game asset.'


def config():
    value = read_json(HERE / 'config.json')
    for key in ('python', 'blender', 'godot', 'comfy_output', 'comfy_main'):
        value[key] = str((ROOT / value[key]).resolve())
    return value


def graph_for(stage, spec, token):
    graph = read_json(HERE / 'templates' / (stage + '.json'))
    if stage == 'concept':
        graph['3']['inputs']['value'] = spec['prompt']
        graph['4']['inputs']['value'] = DEFAULT_COMPOSITION
        graph['5']['inputs']['value'] = spec['finish']
        graph['15']['inputs'].update(width=1024, height=1024, batch_size=1)
        graph['16']['inputs']['seed'] = spec['seed']
        graph['18']['inputs']['filename_prefix'] = f'TelosPipeline/{token}/concept'
    else:
        graph['68']['inputs']['resolution'] = spec['resolution']
        for node in ('82', '83'):
            graph[node]['inputs']['seed'] = spec['seed']
        graph['86']['inputs']['filename_prefix'] = f'TelosPipeline/{token}/mesh'
        graph['101']['inputs']['filename_prefix'] = f'TelosPipeline/{token}/conditioning'
        if spec.get('cleanup') == 'conservative':
            graph['97']['inputs'].update({'remesh': 'off', 'remesh.fill_holes': False,
                'remesh.fill_holes_perimeter': 0.03, 'floater_threshold': 0.0})
            graph['97']['inputs'].pop('remesh.remesh_band', None)
            graph['97']['inputs'].pop('remesh.remove_inner_faces', None)
        elif spec.get('cleanup') == 'preserve-shell':
            graph['97']['inputs'].update({'remesh.remove_inner_faces': False, 'floater_threshold': 0.0})
        if spec.get('audit_mesh'):
            graph['110'] = {'class_type': 'Trellis2ExportTrimesh', 'inputs': {
                'trimesh': ['82', 0], 'filename_prefix': f'TelosPipeline/{token}/before_cleanup', 'file_format': 'glb'}}
        if spec.get('shape_image'):
            graph['102'] = {'class_type': 'LoadImage', 'inputs': {'image': 'shape.png'}}
            graph['103'] = {'class_type': 'Trellis2GetConditioning', 'inputs': {
                'model_config': ['68', 0], 'image': ['102', 0], 'mask': ['100', 1], 'background_color': 'black'}}
            graph['82']['inputs']['conditioning'] = ['103', 0]
            # Original reference still guides texture; shared mask keeps crops aligned.
            graph['104'] = {'class_type': 'SaveImage', 'inputs': {'images': ['103', 1],
                'filename_prefix': f'TelosPipeline/{token}/shape_conditioning'}}
    return graph


def complete(manifest, stage, files):
    manifest['stages'].setdefault(stage, {}).update(status='complete', files={name: digest(path) for name, path in files.items()})


def create(args):
    safe_name(args.name)
    if not args.image and not args.glb and not args.prompt:
        raise ValueError('Provide --prompt, --image or --glb.')
    if not 0 <= args.seed <= 2147483647:
        raise ValueError('Seed must be between 0 and 2147483647.')
    if not 1000 <= args.triangles <= 100000 or not 0.1 <= args.height <= 100:
        raise ValueError('Use 1000–100000 triangles and a height of 0.1–100 metres.')
    for source, suffix in ((args.image, '.png'), (args.glb, '.glb')):
        if source and (not Path(source).is_file() or Path(source).suffix.lower() != suffix):
            raise ValueError(f'Input must be an existing {suffix} file: {source}')
    shape_image = getattr(args, 'shape_image', None)
    if shape_image:
        if not args.image or args.glb:
            raise ValueError('--shape-image requires --image with an aligned original PNG.')
        def dimensions(path):
            with Path(path).open('rb') as stream:
                header = stream.read(24)
            if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR':
                raise ValueError('Shape and original references must be valid PNG files.')
            return struct.unpack('>II', header[16:24])
        if dimensions(shape_image) != dimensions(args.image):
            raise ValueError('Shape and original PNG dimensions must match; preserve their alignment.')
    run_id = args.name + '-' + datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6]
    directory = within(RUNS, RUNS / run_id)
    directory.mkdir(parents=True)
    spec = {'name': args.name, 'prompt': args.prompt or '', 'finish': args.finish, 'seed': args.seed,
            'height': args.height, 'triangles': args.triangles, 'resolution': args.resolution,
            'yaw': args.yaw, 'kind': args.kind}
    spec.update(cleanup=getattr(args, 'cleanup', 'legacy'), audit_mesh=getattr(args, 'audit_mesh', False),
                shape_image=bool(getattr(args, 'shape_image', None)))
    manifest = {'version': 1, 'run_id': run_id, 'spec': spec, 'spec_hash': spec_hash(spec),
                'config': config(), 'stages': {}}
    manifest['implementation_sha256'] = {name: digest(HERE / name) for name in
        ('pipeline.py', 'comfy.py', 'common.py', 'blender_prepare.py', 'verify_import.gd',
         'templates/concept.json', 'templates/mesh.json')}
    if args.image:
        shutil.copy2(args.image, directory / 'concept.png')
        complete(manifest, 'concept', {'concept.png': directory / 'concept.png'})
        manifest['source_image'] = str(Path(args.image).resolve())
    if getattr(args, 'shape_image', None):
        shutil.copy2(args.shape_image, directory / 'shape.png')
        manifest['stages']['concept']['files']['shape.png'] = digest(directory / 'shape.png')
    if args.glb:
        shutil.copy2(args.glb, directory / 'raw.glb')
        complete(manifest, 'mesh', {'raw.glb': directory / 'raw.glb'})
        manifest['source_glb'] = str(Path(args.glb).resolve())
    write_json(directory / 'manifest.json', manifest)
    print(run_id)
    print(f'Next: .\\assets.ps1 run {run_id} --to ' + ('prepare' if args.glb else 'mesh' if args.image else 'concept'))
    return run_id


def load_run(run_id):
    # Accept the printed run ID only, never arbitrary paths supplied through the CLI.
    if '/' in run_id or '\\' in run_id or '..' in run_id:
        raise ValueError('Use a run ID printed by new/status, not a path.')
    directory = within(RUNS, RUNS / run_id)
    manifest = read_json(directory / 'manifest.json')
    if manifest['version'] != 1 or spec_hash(manifest['spec']) != manifest['spec_hash']:
        raise ValueError('Manifest settings changed. Create a new run instead of editing a completed run.')
    return directory, manifest


def verify_files(directory, record):
    for name, expected in record.get('files', {}).items():
        path = within(directory, directory / name)
        if not path.is_file() or digest(path) != expected:
            raise RuntimeError(f'Artifact missing or changed: {path}. Create a new run from the edited image/GLB.')


def execute(command, log, timeout):
    print('Running', Path(command[0]).name, '— log:', log, flush=True)
    with Path(log).open('w', encoding='utf-8') as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f'Process exited with {result.returncode}; see {log}')


def generate(stage, directory, manifest, save):
    cfg, spec = manifest['config'], manifest['spec']
    record = manifest['stages'].setdefault(stage, {'token': uuid.uuid4().hex, 'status': 'new'})
    if record['status'] == 'failed':
        raise RuntimeError(f'{stage} failed previously; inspect its history and create a new run after correcting the issue.')
    client = Comfy(cfg[stage + '_url'])
    graph_file = directory / (stage + '-api.json')
    if graph_file.exists():
        if record.get('graph_sha256') and digest(graph_file) != record['graph_sha256']:
            raise RuntimeError('Saved API graph was edited; create a new run to avoid resuming with different settings.')
        graph = read_json(graph_file)
    else:
        graph = graph_for(stage, spec, record['token'])
        client.validate(graph)
        if stage == 'mesh':
            graph['1']['inputs']['image'] = client.upload(directory / 'concept.png', record['token'] + '.png')
            if spec.get('shape_image'):
                graph['102']['inputs']['image'] = client.upload(directory / 'shape.png', record['token'] + '-shape.png')
        write_json(graph_file, graph)
    record['graph_sha256'] = digest(graph_file)
    save()
    history = client.run(graph, directory, stage, record, save, cfg['timeout_seconds'])
    if stage == 'concept':
        client.download_image(history, '18', directory / 'concept.png')
        files = {'concept.png': directory / 'concept.png'}
    else:
        # This wrapper returns no GLB in history. A unique per-job directory makes
        # export discovery unambiguous, even when another user generates assets.
        output = within(cfg['comfy_output'], Path(cfg['comfy_output']) / 'TelosPipeline' / record['token'])
        candidates = list(output.glob('mesh_*.glb'))
        if len(candidates) != 1:
            raise RuntimeError(f'Expected exactly one GLB in {output}, found {len(candidates)}. Check comfy_output in the run config.')
        shutil.copy2(candidates[0], directory / 'raw.glb')
        client.download_image(history, '101', directory / 'conditioning.png')
        files = {'raw.glb': directory / 'raw.glb', 'conditioning.png': directory / 'conditioning.png'}
        if spec.get('audit_mesh'):
            snapshots = list(output.glob('before_cleanup_*.glb'))
            if len(snapshots) != 1:
                raise RuntimeError('Expected exactly one before-cleanup mesh.')
            shutil.copy2(snapshots[0], directory / 'before-cleanup.glb')
            files['before-cleanup.glb'] = directory / 'before-cleanup.glb'
        if spec.get('shape_image'):
            client.download_image(history, '104', directory / 'shape-conditioning.png')
            files['shape-conditioning.png'] = directory / 'shape-conditioning.png'
    complete(manifest, stage, files)
    save()


def prepare(directory, manifest, save):
    cfg = manifest['config']
    execute([cfg['blender'], '--background', '--factory-startup', '--python-exit-code', '1',
             '--python', str(HERE / 'blender_prepare.py'), '--', str(directory)], directory / 'prepare.log', cfg['timeout_seconds'])
    report = read_json(directory / 'asset-report.json')
    if report['triangles'] > manifest['spec']['triangles'] * 1.02:
        raise RuntimeError('Prepared mesh exceeds triangle budget; inspect asset-report.json.')
    complete(manifest, 'prepare', {name: directory / name for name in ('prepared.glb', 'prepared.blend', 'asset-report.json', 'preview.png')})
    save()


def import_asset(directory, manifest, save):
    cfg = manifest['config']
    dest = within(ROOT / 'prototype/assets/generated', ROOT / 'prototype/assets/generated' / manifest['run_id'])
    if dest.exists() and not (dest / '.pipeline-owner').exists():
        raise RuntimeError(f'Refusing to overwrite an existing unmanaged directory: {dest}')
    if dest.exists() and (dest / '.pipeline-owner').read_text() != manifest['run_id']:
        raise RuntimeError('Destination belongs to a different pipeline run.')
    dest.mkdir(parents=True, exist_ok=True)
    (dest / '.pipeline-owner').write_text(manifest['run_id'])
    asset = dest / 'model.glb'
    if asset.exists() and digest(asset) != digest(directory / 'prepared.glb'):
        raise RuntimeError('Imported GLB was modified. Use a new run; it will not be overwritten.')
    shutil.copy2(directory / 'prepared.glb', asset)
    resource = 'res://' + asset.relative_to(ROOT / 'prototype').as_posix()
    scene = '[gd_scene format=3]\n\n[ext_resource type="PackedScene" path="' + resource + '" id="1"]\n\n[node name="GeneratedAsset" type="Node3D"]\n\n[node name="Model" parent="." instance=ExtResource("1")]\n'
    scene_file = dest / 'asset.tscn'
    if scene_file.exists() and scene_file.read_text() != scene:
        raise RuntimeError('Imported scene was edited; refusing to replace it.')
    scene_file.write_text(scene)
    execute([cfg['godot'], '--headless', '--path', str(ROOT / 'prototype'), '--editor', '--import'], directory / 'import.log', 180)
    scene_resource = 'res://' + scene_file.relative_to(ROOT / 'prototype').as_posix()
    execute([cfg['godot'], '--headless', '--path', str(ROOT / 'prototype'), '--script', str(HERE / 'verify_import.gd'), '--', scene_resource], directory / 'verify-import.log', 60)
    if 'ASSET_IMPORT_VERIFIED' not in (directory / 'verify-import.log').read_text():
        raise RuntimeError('Godot did not confirm import; inspect verify-import.log.')
    manifest['imported_scene'] = str(scene_file.relative_to(ROOT))
    manifest['stages']['import'] = {'status': 'complete', 'files': {}, 'glb_sha256': digest(asset), 'scene_sha256': digest(scene_file)}
    save()


def run(args):
    directory, manifest = load_run(args.run_id)
    with run_lock(directory):
        # Reload after acquiring the lock.
        directory, manifest = load_run(args.run_id)
        def save():
            write_json(directory / 'manifest.json', manifest)
        start = 1 if manifest.get('source_glb') else 0
        for stage in STAGES[start:STAGES.index(args.to) + 1]:
            record = manifest['stages'].get(stage, {})
            if record.get('status') == 'complete':
                verify_files(directory, record)
                if stage == 'import':
                    dest = ROOT / manifest['imported_scene']
                    if digest(dest) != record['scene_sha256'] or digest(dest.with_name('model.glb')) != record['glb_sha256']:
                        raise RuntimeError('Imported files changed; preserve your edits and use a new run.')
                print(stage + ': already complete (verified)')
                continue
            if stage in ('concept', 'mesh'):
                generate(stage, directory, manifest, save)
            elif stage == 'prepare':
                prepare(directory, manifest, save)
            else:
                import_asset(directory, manifest, save)
            print(stage + ': complete', flush=True)
        print('Review:', directory)
        if manifest.get('imported_scene'):
            print('Drag into Godot:', manifest['imported_scene'])


def doctor():
    cfg = config()
    failed = False
    for key in ('python', 'blender', 'godot', 'comfy_output'):
        ok = Path(cfg[key]).exists()
        print(('OK ' if ok else 'MISSING ') + key + ': ' + cfg[key])
        failed |= not ok
    for stage in ('concept', 'mesh'):
        try:
            Comfy(cfg[stage + '_url']).validate(read_json(HERE / 'templates' / (stage + '.json')))
            print('OK ' + stage + ' nodes: ' + cfg[stage + '_url'])
        except Exception as error:
            failed = True
            print('UNAVAILABLE', stage, str(error))
    return int(failed)


def serve():
    cfg = config()
    if cfg['concept_url'] != cfg['mesh_url']:
        raise ValueError('serve supports one shared server. Start separate configured servers manually.')
    client = Comfy(cfg['concept_url'])
    try:
        client.get('/system_stats')
        print('ComfyUI is already running at', client.url)
        return
    except Exception:
        pass
    port = urlparse(client.url).port or 8188
    print('Starting local ComfyUI. Leave this terminal open; run assets.ps1 in another terminal.', flush=True)
    command = [cfg['python'], '-u', cfg['comfy_main'], '--windows-standalone-build',
               '--disable-auto-launch', '--disable-dynamic-vram', '--disable-pinned-memory',
               '--disable-async-offload', '--disable-smart-memory', '--port', str(port),
               '--disable-all-custom-nodes', '--whitelist-custom-nodes', 'ComfyUI-TRELLIS2', 'ComfyUI-GeometryPack']
    subprocess.run(command, cwd=Path(cfg['comfy_main']).parent, check=True)


def main():
    from shape_reference import add_arguments, run as run_shape
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    add_arguments(sub.add_parser('shape', help='Experimental local clay Img2Img reference; review before mesh generation.'))
    new = sub.add_parser('new', help='Create a new immutable run; no GPU work yet.')
    new.add_argument('name')
    source = new.add_mutually_exclusive_group()
    source.add_argument('--image', help='Existing PNG concept; skips generation.')
    source.add_argument('--glb', help='Existing static GLB; skips both AI stages.')
    new.add_argument('--prompt')
    new.add_argument('--shape-image', help='Experimental aligned PNG for geometry; --image still guides textures.')
    new.add_argument('--cleanup', choices=('legacy', 'conservative', 'preserve-shell'), default='legacy')
    new.add_argument('--audit-mesh', action='store_true', help='Also retain the dense mesh before TRELLIS cleanup (large file).')
    new.add_argument('--finish', default='Worn ochre and charcoal painted metal, restrained cyan accent light. Broad clean surfaces with sparse purposeful wear.')
    new.add_argument('--seed', type=int, default=42)
    new.add_argument('--resolution', choices=('512', '1024_cascade'), default='512')
    new.add_argument('--triangles', type=int, default=22000)
    new.add_argument('--height', type=float, default=1.8)
    new.add_argument('--yaw', type=float, default=180, help='Rotate around vertical axis in degrees. Default converts tested TRELLIS facing to Godot -Z.')
    new.add_argument('--kind', choices=('prop', 'hero'), default='prop', help='Documentation tag; all outputs are static visual scenes.')
    new.add_argument('--to', choices=STAGES, help='Optionally start immediately and continue through this stage.')
    go = sub.add_parser('run', help='Resume up to a stage. Default stops for concept review.')
    go.add_argument('run_id')
    go.add_argument('--to', choices=STAGES, default='concept')
    sub.add_parser('doctor', help='Read-only local dependency and node checks.')
    sub.add_parser('serve', help='Start the installed ComfyUI in this terminal, or reuse it if running.')
    status = sub.add_parser('status')
    status.add_argument('run_id', nargs='?')
    args = parser.parse_args()
    if args.command == 'shape':
        run_shape(args)
        return 0
    if args.command == 'doctor':
        return doctor()
    if args.command == 'serve':
        serve()
        return 0
    if args.command == 'new':
        args.run_id = create(args)
        if args.to:
            run(args)
    elif args.command == 'run':
        run(args)
    else:
        paths = [load_run(args.run_id)[0] / 'manifest.json'] if args.run_id else sorted(RUNS.glob('*/manifest.json'))
        for path in paths:
            m = read_json(path)
            print(m['run_id'], ' '.join(f"{s}={m['stages'].get(s, {}).get('status', 'not-started')}" for s in STAGES))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print('\nStopped waiting. ComfyUI work may still be running; use the same run ID to resume.', file=sys.stderr)
        sys.exit(130)
    except Exception as error:
        print('ERROR:', error, file=sys.stderr)
        sys.exit(1)
