import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from maps import OUT,read_json,validate,graph

class MapContractTests(unittest.TestCase):
    def setUp(self):self.m=read_json(OUT/'act_01.draft.json')
    def test_valid_route(self):self.assertTrue(validate(self.m))
    def test_duplicate_ids(self):
        self.m['nodes'][1]['id']=self.m['nodes'][0]['id']
        with self.assertRaises(AssertionError):validate(self.m)
    def test_cycle(self):
        self.m['nodes'][0]['prerequisites']=[self.m['nodes'][-1]['id']]
        with self.assertRaises(AssertionError):validate(self.m)
    def test_well_count_and_identity(self):
        self.m['nodes'][4]['well_id']='well_1'
        with self.assertRaises(AssertionError):validate(self.m)
    def test_position_nan(self):
        self.m['nodes'][2]['position'][0]=float('nan')
        with self.assertRaises(AssertionError):validate(self.m)
    def test_path_does_not_match_node(self):
        self.m['paths'][0]['points'][1]=[.5,.5]
        with self.assertRaises(AssertionError):validate(self.m)
    def test_real_reference_latent_connection(self):
        g=graph('A_valley',123,'reference.png',.55)
        self.assertEqual(g['16']['inputs']['latent_image'],['15',0])
        self.assertEqual(g['15']['class_type'],'VAEEncode')
        self.assertEqual(g['15']['inputs']['pixels'],['21',0])
        self.assertEqual(g['21']['inputs']['image'],['20',0])
        self.assertEqual(g['16']['inputs']['denoise'],.55)
    def test_concept_has_no_reference_dependency(self):
        g=graph('C_terraces',456)
        self.assertEqual(g['15']['class_type'],'EmptyLatentImage')
        self.assertNotIn('20',g)

if __name__=='__main__':unittest.main()
