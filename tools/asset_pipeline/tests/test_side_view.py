"""Offline integrity checks for the shipped native and API workflow pairs."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
folder = root / 'art/side-view/workflows'
files = sorted(p for p in folder.glob('*.json') if not p.name.endswith('.api.json'))
assert files
api_names = {p.name[:-len('.api.json')] for p in folder.glob('*.api.json')}
assert {p.stem for p in files} == api_names
assert '06_cutout' in {p.stem for p in files}
environment_dimensions = {
    '07_environment_backdrop': [1536, 864, 1],
    '08_environment_lane': [1536, 512, 1],
    '09_environment_dressing': [1024, 1024, 1],
}
for path in files:
    workflow = json.loads(path.read_text())
    api = json.loads(path.with_suffix('.api.json').read_text())
    nodes = {n['id']: n for n in workflow['nodes']}
    for link, source, slot, target, inlet, typ in workflow['links']:
        assert link in nodes[source]['outputs'][slot]['links']
        assert nodes[target]['inputs'][inlet]['link'] == link
        name = nodes[target]['inputs'][inlet]['name']
        assert api[str(target)]['inputs'][name] == [str(source), slot]
    for key, node in api.items():
        assert nodes[int(key)]['type'] == node['class_type']
    if path.stem != '06_cutout':
        for key in ('1', '2', '3', '4', '5'):
            assert nodes[int(key)]['widgets_values'][0] == api[key]['inputs']['value']
        expected_dimensions = environment_dimensions.get(path.stem, [1024, 1024, 1])
        assert nodes[15]['widgets_values'] == expected_dimensions
        assert nodes[16]['widgets_values'][0] == api['16']['inputs']['seed']
        assert nodes[16]['widgets_values'][1] == 'fixed'
print(f'{len(files)} native/API workflow pairs: links, types, prompt blocks, dimensions and seeds verified')
