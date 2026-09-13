"""Decode a source video to timestamped PNGs and an unaltered-frame contact sheet."""
import argparse
import hashlib
import json
from pathlib import Path
import av
from PIL import Image, ImageDraw

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('video', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    frames_dir = args.output / 'frames'
    frames_dir.mkdir()
    rows = []
    with av.open(str(args.video)) as container:
        stream = container.streams.video[0]
        info = {'source': str(args.video.resolve()), 'sha256': hashlib.sha256(args.video.read_bytes()).hexdigest(), 'codec': stream.codec_context.name, 'width': stream.width, 'height': stream.height, 'fps': str(stream.average_rate), 'audio_streams': len(container.streams.audio)}
        for index, frame in enumerate(container.decode(stream)):
            name = f'frame_{index:04d}.png'
            frame.to_image().save(frames_dir / name)
            rows.append({'index': index, 'time_seconds': float(frame.time), 'codec_keyframe': bool(frame.key_frame), 'file': 'frames/' + name})
    info['frame_count'] = len(rows)
    info['last_timestamp_seconds'] = rows[-1]['time_seconds']
    info['frames'] = rows
    indices = sorted(set(round(i*(len(rows)-1)/15) for i in range(16)))
    sheet = Image.new('RGB', (1024, 4*280), '#20262b')
    draw = ImageDraw.Draw(sheet)
    for slot, index in enumerate(indices):
        im = Image.open(args.output / rows[index]['file']).convert('RGB')
        im.thumbnail((250, 250))
        x, y = (slot % 4)*256, (slot // 4)*280
        sheet.paste(im, (x+(256-im.width)//2, y))
        draw.text((x+8, y+254), f"{index:03d} / {rows[index]['time_seconds']:.3f}s", fill='white')
    sheet.save(args.output / 'contact-sheet.png')
    (args.output / 'frames.json').write_text(json.dumps(info, indent=2)+'\n')
    print(json.dumps({k:v for k,v in info.items() if k != 'frames'}, indent=2))

if __name__ == '__main__':
    main()
