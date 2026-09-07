import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, Mock
from types import SimpleNamespace
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import safe_name, within, write_json, digest, run_lock
from comfy import Comfy
from pipeline import graph_for, verify_files, create, load_run, import_asset


class PipelineTests(unittest.TestCase):
    def test_shape_reference_does_not_replace_texture_reference(self):
        graph = graph_for('mesh', {'seed': 42, 'resolution': '512', 'shape_image': True,
                                  'cleanup': 'conservative', 'audit_mesh': True}, 'test')
        self.assertEqual(graph['82']['inputs']['conditioning'], ['103', 0])
        self.assertEqual(graph['83']['inputs']['conditioning'], ['69', 0])
        self.assertEqual(graph['103']['inputs']['mask'], graph['69']['inputs']['mask'])
        self.assertEqual(graph['110']['inputs']['trimesh'], ['82', 0])
        self.assertEqual(graph['97']['inputs']['remesh'], 'off')
        self.assertFalse(graph['97']['inputs']['remesh.fill_holes'])
        self.assertNotIn('remesh.remove_inner_faces', graph['97']['inputs'])

    def test_misaligned_dimensions_rejected_before_run_creation(self):
        import struct
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, size in [('original', 1024), ('shape', 512)]:
                (root/(name+'.png')).write_bytes(b'\x89PNG\r\n\x1a\n'+b'\x00\x00\x00\x0dIHDR'+struct.pack('>II', size, size))
            args = SimpleNamespace(name='test', image=str(root/'original.png'), shape_image=str(root/'shape.png'),
                                   glb=None, prompt=None, seed=42, triangles=12000, height=1.5)
            with patch('pipeline.RUNS', root/'runs'):
                with self.assertRaisesRegex(ValueError, 'dimensions must match'):
                    create(args)
                self.assertFalse((root/'runs').exists())

    def test_shell_preset_retains_remeshing_without_inner_face_removal(self):
        spec = {'seed': 42, 'resolution': '512', 'cleanup': 'preserve-shell'}
        inputs = graph_for('mesh', spec, 'test')['97']['inputs']
        self.assertEqual(inputs['remesh'], 'on')
        self.assertFalse(inputs['remesh.remove_inner_faces'])
        self.assertEqual(inputs['floater_threshold'], 0.0)

    def test_completed_shape_job_rejects_changed_output_without_gpu_work(self):
        from shape_reference import run
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root/'source.png'
            source.write_bytes(b'source')
            output = root/'clay.png'
            output.write_bytes(b'original')
            write_json(root/'api.json', {'3': {'inputs': {'value': 'clay'}}, '16': {'inputs': {'seed': 42}}})
            write_json(root/'job.json', {'source_sha256': digest(source), 'denoise': .55,
                                       'status': 'complete', 'output_sha256': digest(output)})
            output.write_bytes(b'changed')
            args = SimpleNamespace(image=source, out=root, denoise=.55, prompt=None, seed=None)
            with patch('shape_reference.Comfy') as client:
                with self.assertRaisesRegex(ValueError, 'missing or changed'):
                    run(args)
                client.return_value.run.assert_not_called()

    def test_existing_glb_skips_ai_and_is_copied(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root/'source.glb'
            source.write_bytes(b'test-source')
            args = SimpleNamespace(name='test', image=None, glb=str(source), prompt=None, seed=42,
                                   triangles=12000, height=1.5, finish='ochre', resolution='512', yaw=180, kind='prop')
            with patch('pipeline.RUNS', root/'runs'), patch('pipeline.config', return_value={}):
                run_id = create(args)
                directory, manifest = load_run(run_id)
                self.assertEqual(manifest['stages']['mesh']['status'], 'complete')
                self.assertEqual((directory/'raw.glb').read_bytes(), source.read_bytes())
                manifest['spec']['height'] = 8
                write_json(directory/'manifest.json', manifest)
                with self.assertRaisesRegex(ValueError, 'settings changed'):
                    load_run(run_id)

    def test_import_refuses_unmanaged_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'prototype/assets/generated/test-run').mkdir(parents=True)
            with patch('pipeline.ROOT', root), patch('pipeline.execute') as execute:
                with self.assertRaisesRegex(RuntimeError, 'unmanaged'):
                    import_asset(root, {'config': {}, 'run_id': 'test-run'}, lambda: None)
                execute.assert_not_called()

    def test_output_names_reject_path_injection(self):
        for name in ('../other', 'a/b', 'a\\b', 'A', 'x"bad', ''):
            with self.assertRaises(ValueError):
                safe_name(name)
        self.assertEqual(safe_name('coolant-pump_2'), 'coolant-pump_2')

    def test_output_containment(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                within(tmp, Path(tmp) / '../outside')
            with self.assertRaises(ValueError):
                within(tmp, tmp)

    def test_changed_artifact_is_not_silently_reused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'raw.glb').write_bytes(b'original')
            record = {'files': {'raw.glb': digest(root/'raw.glb')}}
            verify_files(root, record)
            (root/'raw.glb').write_bytes(b'edited')
            with self.assertRaises(RuntimeError):
                verify_files(root, record)

    def test_remote_server_is_not_accepted(self):
        with self.assertRaises(ValueError):
            Comfy('https://example.com')

    def test_resume_polls_existing_job_without_post(self):
        client = Comfy('http://127.0.0.1:8188')
        completed = {'status': {'completed': True, 'status_str': 'success'}, 'outputs': {}}
        with tempfile.TemporaryDirectory() as tmp, patch.object(client, 'get', return_value={'known': completed}), patch('comfy.requests.post') as post:
            result = client.run({}, Path(tmp), 'mesh', {'prompt_id': 'known'}, lambda: None, 5)
            self.assertEqual(result, completed)
            post.assert_not_called()
            self.assertTrue((Path(tmp)/'mesh-history.json').is_file())

    def test_uncertain_submission_recovers_job_without_resubmitting(self):
        client = Comfy('http://127.0.0.1:8188')
        record = {'status': 'submitting', 'token': 'unique'}
        done = {'status': {'completed': True, 'status_str': 'success'}}
        with tempfile.TemporaryDirectory() as tmp, patch.object(client, 'find_job', return_value='recovered'), patch.object(client, 'get', return_value={'recovered': done}), patch('comfy.requests.post') as post:
            client.run({}, Path(tmp), 'concept', record, lambda: None, 5)
            self.assertEqual(record['prompt_id'], 'recovered')
            post.assert_not_called()

    def test_unknown_submission_stops_without_duplicate(self):
        client = Comfy('http://127.0.0.1:8188')
        with tempfile.TemporaryDirectory() as tmp, patch.object(client, 'find_job', return_value=None), patch('comfy.requests.post') as post:
            with self.assertRaisesRegex(RuntimeError, 'unknown'):
                client.run({}, Path(tmp), 'mesh', {'status': 'submitting', 'token': 'x'}, lambda: None, 5)
            post.assert_not_called()

    def test_server_failure_is_saved(self):
        client = Comfy('http://127.0.0.1:8188')
        failure = {'status': {'status_str': 'error', 'messages': ['GPU failure']}}
        record = {'prompt_id': 'job'}
        save = Mock()
        with tempfile.TemporaryDirectory() as tmp, patch.object(client, 'get', return_value={'job': failure}):
            with self.assertRaises(RuntimeError):
                client.run({}, Path(tmp), 'mesh', record, save, 5)
            self.assertEqual(record['status'], 'failed')
            save.assert_called()

    def test_busy_server_does_not_submit_or_unload_models(self):
        client = Comfy('http://127.0.0.1:8188')
        with tempfile.TemporaryDirectory() as tmp, patch.object(client, 'validate'), patch.object(client, 'get', return_value={'queue_running': [['other']]}), patch('comfy.requests.post') as post:
            with self.assertRaisesRegex(RuntimeError, 'busy'):
                client.run({}, Path(tmp), 'mesh', {'status': 'new', 'token': 'x'}, lambda: None, 5)
            post.assert_not_called()

    def test_prompt_binding_preserves_style_and_isolates_outputs(self):
        spec = {'prompt': 'test pump', 'finish': 'ochre', 'seed': 7, 'resolution': '512'}
        first = graph_for('concept', spec, 'a')
        second = graph_for('concept', spec, 'b')
        self.assertEqual(first['3']['inputs']['value'], 'test pump')
        self.assertEqual(first['1'], second['1'])
        self.assertNotEqual(first['18'], second['18'])
        self.assertEqual(first['15']['inputs']['batch_size'], 1)


if __name__ == '__main__':
    unittest.main()
