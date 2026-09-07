"""ComfyUI transport and recoverable jobs. Never silently resubmit uncertain work."""
import time
from pathlib import Path
from urllib.parse import urlparse
import requests
from common import write_json


class Comfy:
    def __init__(self, url):
        if urlparse(url).hostname not in ('localhost', '127.0.0.1', '::1'):
            raise ValueError('Only a local ComfyUI server is supported.')
        self.url = url.rstrip('/')

    def get(self, endpoint):
        result = requests.get(self.url + endpoint, timeout=30)
        result.raise_for_status()
        return result.json()

    def validate(self, graph):
        info = self.get('/object_info')
        missing = sorted({n['class_type'] for n in graph.values()} - info.keys())
        if missing:
            raise RuntimeError('Missing nodes: ' + ', '.join(missing) + '. Load the matching ComfyUI workflows first; see tools/asset_pipeline/README.md.')
        for node in graph.values():
            schema = info[node['class_type']].get('input', {})
            fields = {**schema.get('required', {}), **schema.get('optional', {})}
            for name in ('unet_name', 'clip_name', 'vae_name'):
                if name in node['inputs'] and name in fields and isinstance(fields[name][0], list):
                    if node['inputs'][name] not in fields[name][0]:
                        raise RuntimeError(f"Missing model {node['inputs'][name]} for {node['class_type']}.")

    def upload(self, image, name):
        with Path(image).open('rb') as stream:
            result = requests.post(self.url + '/upload/image', files={'image': (name, stream, 'image/png')}, timeout=60)
        result.raise_for_status()
        data = result.json()
        return '/'.join(filter(None, (data.get('subfolder'), data['name'])))

    def find_job(self, token):
        queue = self.get('/queue')
        for row in queue.get('queue_running', []) + queue.get('queue_pending', []):
            if len(row) > 3 and row[3].get('telos_job') == token:
                return row[1]
        for job_id, item in self.get('/history').items():
            prompt = item.get('prompt', [])
            if len(prompt) > 3 and prompt[3].get('telos_job') == token:
                return job_id
        return None

    def run(self, graph, directory, stage, record, save, timeout):
        if not record.get('prompt_id'):
            if record.get('status') == 'submitting':
                recovered = self.find_job(record['token'])
                if not recovered:
                    raise RuntimeError('Submission outcome is unknown. Inspect ComfyUI history. This command will not submit again; use a new run if the server lost the job.')
                record['prompt_id'] = recovered
                save()
            else:
                self.validate(graph)
                queue = self.get('/queue')
                if queue.get('queue_running') or queue.get('queue_pending'):
                    raise RuntimeError('ComfyUI is busy. Wait for its queue to clear, then resume.')
                # Release models from the preceding stage before starting a different model family.
                result = requests.post(self.url + '/free', json={'unload_models': True, 'free_memory': True}, timeout=30)
                result.raise_for_status()
                record['status'] = 'submitting'
                save()
                response = requests.post(self.url + '/prompt', json={'prompt': graph, 'extra_data': {'telos_job': record['token']}}, timeout=60)
                if response.status_code == 400:
                    record['status'] = 'failed'
                    record['error'] = response.text
                    save()
                response.raise_for_status()
                record['prompt_id'] = response.json()['prompt_id']
                record['status'] = 'queued'
                save()
        deadline = time.monotonic() + timeout
        print(f"{stage}: job {record['prompt_id']} on {self.url}", flush=True)
        while time.monotonic() < deadline:
            history = self.get('/history/' + record['prompt_id'])
            if record['prompt_id'] in history:
                result = history[record['prompt_id']]
                write_json(directory / (stage + '-history.json'), result)
                status = result.get('status', {})
                if status.get('status_str') == 'error':
                    record['status'] = 'failed'
                    record['error'] = str(status.get('messages', []))[-4000:]
                    save()
                    raise RuntimeError(f'{stage} failed. See {stage}-history.json; create a new run after fixing the reported dependency/input issue.')
                if status.get('completed') and status.get('status_str') == 'success':
                    return result
            time.sleep(3)
        raise TimeoutError('Still waiting; job identity is saved. Run the same command to resume polling. Ctrl+C does not cancel the ComfyUI job.')

    def download_image(self, result, node, destination):
        images = result.get('outputs', {}).get(node, {}).get('images', [])
        if len(images) != 1:
            raise RuntimeError(f'Expected one image from node {node}; received {len(images)}.')
        response = requests.get(self.url + '/view', params=images[0], timeout=60)
        response.raise_for_status()
        Path(destination).write_bytes(response.content)
