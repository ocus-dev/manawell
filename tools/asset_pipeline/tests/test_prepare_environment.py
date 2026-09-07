import hashlib
import json
import sys
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/asset_pipeline'))
from prepare_environment import GROUND_Y, LANE_HEIGHT, LOGICAL_SIZE


class PrepareEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.destination = ROOT / 'prototype/assets/side-view/environment'
        self.manifest = json.loads((self.destination / 'environment-manifest.json').read_text())

    def test_manifest_and_runtime_outputs(self):
        self.assertEqual(self.manifest['logical_canvas'], list(LOGICAL_SIZE))
        self.assertEqual(self.manifest['ground_y'], GROUND_Y)
        layers = {layer['layer']: layer for layer in self.manifest['layers']}
        self.assertEqual(layers['backdrop']['prepared_dimensions'], list(LOGICAL_SIZE))
        self.assertEqual(layers['service_lane']['prepared_dimensions'], [LOGICAL_SIZE[0], LANE_HEIGHT])
        self.assertEqual(layers['service_lane']['logical_placement'], [0, GROUND_Y])
        self.assertEqual(layers['service_lane']['top_edge_y'], GROUND_Y)
        self.assertEqual(layers['edge_dressing']['output_path'], None)
        for layer in layers.values():
            if layer['output_path'] is not None:
                output = ROOT / layer['output_path']
                self.assertTrue(output.is_file(), output)
                self.assertEqual(hashlib.sha256(output.read_bytes()).hexdigest(), layer['output_sha256'])

    def test_backdrop_and_lane_are_opaque(self):
        layers = {layer['layer']: layer for layer in self.manifest['layers']}
        for name in ('backdrop', 'service_lane'):
            image = Image.open(ROOT / layers[name]['output_path']).convert('RGBA')
            self.assertEqual(image.getchannel('A').getextrema(), (255, 255))

    def test_review_outputs_match_logical_canvas(self):
        for review in self.manifest['reviews']:
            with Image.open(ROOT / review['path']) as image:
                self.assertEqual(image.size, LOGICAL_SIZE)


if __name__ == '__main__':
    unittest.main()