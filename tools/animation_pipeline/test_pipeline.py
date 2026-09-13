import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from PIL import Image, ImageDraw
from prepare import sequence, sample_indices, export, bounds
from workflows import graph, frame_count

class PipelineTests(unittest.TestCase):
    def sprite(self,x):
        im=Image.new('RGBA',(64,64))
        ImageDraw.Draw(im).rectangle((x,20,x+10,50),fill='red')
        return im

    def test_cadence_and_h3_length(self):
        self.assertEqual(frame_count(3),73)
        self.assertEqual(sample_indices(73,24,12),list(range(0,73,2)))
        with self.assertRaises(ValueError):sample_indices(5,24,60)

    def test_shared_crop_preserves_motion_and_anchor(self):
        frames,info=sequence([self.sprite(10),self.sprite(20)],(32,51),112)
        self.assertEqual(frames[1].getbbox()[0]-frames[0].getbbox()[0],10)
        self.assertEqual(info['ground_anchor'][0]+info['union_crop'][0],32)
        fixed,_=sequence([self.sprite(10),self.sprite(20)],(32,51),112,[[0,0],[-10,0]])
        self.assertEqual(fixed[0].tobytes(),fixed[1].tobytes())

    def test_bad_masks_and_canvas(self):
        with self.assertRaises(ValueError):bounds(Image.new('RGBA',(4,4),'white'))
        with self.assertRaises(ValueError):bounds(Image.new('RGBA',(4,4)))
        with self.assertRaises(ValueError):sequence([self.sprite(10),Image.new('RGBA',(32,32))],(32,51),112)

    def test_export_timing_and_relative_paths(self):
        frames,info=sequence([self.sprite(10),self.sprite(20)],(32,51),112)
        info['last_frame_duration_multiplier']=0.5
        with tempfile.TemporaryDirectory() as tmp:
            export(frames,tmp,info,12,'attack',False)
            text=(Path(tmp)/'godot/animation.tres').read_text()
            self.assertIn('"duration": 0.5',text)
            self.assertIn('"loop": false',text)
            self.assertIn('path="atlas.png"',text)

    def test_generation_outputs_and_endpoint_constraint(self):
        for motion in ('idle','walk','attack'):
            g=graph(motion,'reference.png')
            self.assertEqual(g['1']['inputs']['image'],g['2']['inputs']['image'])
            self.assertEqual(g['17']['inputs']['images'],['13',0])
            self.assertEqual(g['7']['inputs']['length']%17,5)

    def test_shared_reference_does_not_shrink_tall_attack(self):
        idle=self.sprite(10)
        attack=self.sprite(10)
        ImageDraw.Draw(attack).rectangle((10,2,20,19),fill='red')
        _,a=sequence([idle],(32,51),80,reference_height=31)
        _,b=sequence([idle,attack],(32,51),80,reference_height=31)
        self.assertEqual(a['recommended_scale'],b['recommended_scale'])
        with self.assertRaises(ValueError):sequence([idle],(32,51),80,reference_height=float('nan'))

if __name__=='__main__':unittest.main()
