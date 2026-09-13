# Pipeline pilot validation

Source: existing `breaker_animation.mp4`, 576×576, 73 decoded frames at 24 fps. Sampled 37 frames at 12 fps using the installed ComfyUI background remover. All selected frames exported with transparency, a shared 568×542 cell and fixed ground anchor. Resume verified the saved artifact hashes.

Five Python regression tests passed for sampling, shared crop/translation, invalid alpha/canvas rejection, duration export and H3 output/endpoint wiring. Godot 4.8-dev4 imported the atlas and passed a headless probe: 37 SpriteFrames, total duration 73/24 seconds, scene/resource loading and fixed ground pivot. The sandbox prevented Godot user log/editor-settings writes and certificate-store access; resource import and probe succeeded.

Contact sheet reviewed: cutouts retain the changing claw silhouette without independent recentering. The old clip changes feet/pose and is not seamless. Its first/last premultiplied RGB difference is about 0.052, triggering the loop warning. This is a preparation demonstration, not an approved idle/walk/attack asset.

New H3 generation presets are checked against the installed node/model schemas and native link structure. A fresh H3 video generation has not been run as part of this implementation; generation quality and endpoint adherence still require a new take and visual review.
