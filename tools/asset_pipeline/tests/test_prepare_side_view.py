import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_side_view import alpha_bounds, prepare_image


class PrepareSideViewTests(unittest.TestCase):
    def make_image(self, mode='transparent'):
        image = Image.new('RGBA', (20, 20), (20, 30, 40, 0))
        if mode == 'partial':
            image.putpixel((5, 4), (200, 100, 50, 12))
            for y in range(6, 15):
                for x in range(7, 13):
                    image.putpixel((x, y), (200, 100, 50, 255))
        elif mode == 'opaque':
            image = Image.new('RGBA', (20, 20), (20, 30, 40, 255))
        return image

    def test_bounds_use_meaningful_alpha_without_binary_output(self):
        image = self.make_image('partial')
        self.assertEqual(alpha_bounds(image), (5, 4, 13, 15))
        self.assertEqual(image.getpixel((5, 4))[3], 12)

    def test_fully_transparent_and_opaque_inputs_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'fully transparent'):
            alpha_bounds(self.make_image())
        with self.assertRaisesRegex(ValueError, 'fully opaque'):
            alpha_bounds(self.make_image('opaque'))

    def test_crop_padding_and_anchor_transform(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'cutout.png'
            output = Path(directory) / 'derived.png'
            self.make_image('partial').save(source)
            details = prepare_image(source, output, anchor_override=(8, 14), padding=2)
            self.assertEqual(details['crop_rectangle'], [3, 2, 15, 17])
            self.assertEqual(details['visible_bounds'], [5, 4, 13, 15])
            self.assertEqual(details['ground_anchor'], [5, 12])
            self.assertEqual(Image.open(output).getpixel((2, 2))[3], 12)
            with self.assertRaises(FileExistsError):
                prepare_image(source, output, padding=2)


if __name__ == '__main__':
    unittest.main()