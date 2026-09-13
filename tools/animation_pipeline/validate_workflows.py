"""Validate saved native/API pairs against the live installed node schemas."""
import json
from pathlib import Path
import requests
root=Path(__file__).resolve().parents[2]
config=json.loads((root/'tools/asset_pipeline/config.json').read_text())
schemas=requests.get(config['concept_url']+'/object_info',timeout=30).json()
for path in (root/'art/side-view/animations/workflows').glob('*.api.json'):
    api=json.loads(path.read_text())
    ui=json.loads(path.with_name(path.name.replace('.api.json','.json')).read_text())
    nodes={n['id']:n for n in ui['nodes']}
    for key,n in api.items():
        schema=schemas[n['class_type']]
        required=schema['input'].get('required',{})
        fields={**required,**schema['input'].get('optional',{})}
        assert set(required)<=set(n['inputs']),(path,key,'missing required')
        for name,value in n['inputs'].items():
            typ=fields[name][0]
            if isinstance(value,list):
                source,slot=value
                actual=schemas[api[source]['class_type']]['output'][slot]
                assert actual==typ,(path,key,name,actual,typ)
            elif isinstance(typ,list):
                assert value in typ,(path,key,name,value)
            elif isinstance(value,(int,float)):
                options=fields[name][1] if len(fields[name])>1 else {}
                assert options.get('min',float('-inf'))<=value<=options.get('max',float('inf'))
    for ident,source,slot,dest,input_slot,typ in ui['links']:
        assert ident in nodes[source]['outputs'][slot]['links']
        assert nodes[dest]['inputs'][input_slot]['link']==ident
    print('PASS:',path.name,'required inputs, linked types, choices, ranges and native links')
