# Breaker animation assessment

Inspected source: `art/side-view/animations/breaker_animation.mp4` (the actual filename found in the workspace). Original video unchanged. Saved workflow inspected: `D:/Create/comfy_ui/ComfyUI_windows_portable/ComfyUI/user/default/workflows/Asset animation.json`; a read-only snapshot is saved here as `asset-animation-original.json`. Workflow note text was treated as documentation, not instructions to install/update anything.

## What was extracted

- H.264, 576×576, 24 fps, 73 decoded frames; timestamps 0.000 through 3.000 seconds (73 frame intervals at 24 fps occupy approximately 3.042 seconds).
- One audio stream; audio was not evaluated or imported.
- `frames/`: every decoded frame as PNG, preserving its original canvas and background.
- `frames.json`: frame indices, timestamps, codec-keyframe flags and source hash.
- `contact-sheet.png`: 16 evenly spaced frames for visual comparison.
- `keyposes/`: selected review poses at indices 0, 24, 34, 38, 48, 58 and 72. These are visual samples, not a finalized animation timeline.

Codec keyframes are compression anchors, not necessarily useful character poses. PNG extraction cannot recover skeletal joints, editable body layers or lost compressed detail. Background removal and final animation authoring have not been performed on this sequence.

## Suitability

Useful as a first idle/agitation animation source. The breaker keeps its broad identity and roughly consistent framing while its forward claw rises, flexes and lowers. The opening is comparatively still; most obvious claw motion develops after roughly the first second. Dark far-side limbs and the existing angled pose remain visually ambiguous. The final claw/feet pose differs from the start, so the whole clip is not an established seamless loop. It has no unambiguous complete stride or deliberately authored anticipation/contact/recovery cycle: do not designate it a walk/attack purely from the filename or prompt.

Try a low-frame-rate presentation at actual gameplay size before spending more generation time: begin with 12 fps sampling from the 24 fps source, preserve timing, and inspect whether reduced cadence suits the painted style. Do not make all selected poses equal-duration if preserving the original motion is the goal. Compression frames are not animation key poses.

## Concrete workflow findings

1. LoadImage 114 goes directly into first_frame of group 105. The last_frame input is unconnected.
2. ResolutionSelector 115 is 1:1, 0.3 megapixels, multiple 32 and supplies the group's width/height. This is consistent with the 576×576 output. The group's visible 1344/768 widget values are overridden by these links.
3. ImageScaleToTotalPixels 119 has no image input. It only connects to GetImageSize 120, whose result is unused. This branch has no effect on generation. Remove it from an improved copy, or wire a single intentional reference-preparation branch; use a smooth resampler for painted art rather than nearest-exact.
4. Prompt: "Science fiction game asset generation. Monster moves claws up and down while feet shuffle back and forth. No other objects in scene". This mixes idle and locomotion and does not constrain camera, travel, cycle timing, endpoint or silhouette preservation.
5. The local H3 group includes video and audio decoding and CreateVideo at 24 fps, then SaveVideo. It does not expose the decoded frame batch as a saved master sequence. Keep audio-model conditioning intact unless local node support confirms a valid video-only route; omitting audio from the game asset is sufficient.
6. Duration is converted to the model's supported frame grid by the existing expression; retain this mechanism and read actual frame count/timestamps after generation rather than assuming exactly duration×fps frames. The recorded three-second setting resulted in 73 frames.

## Proposed improved pipeline

Keep the original workflow unchanged. Make separate copies/presets for idle-loop, locomotion-in-place, and attack-once. Each uses one named prepared reference, explicit output resolution, recorded seed and motion prompt. Use filenames such as breaker_idle_v01 instead of result.png to avoid confusing references.

**Reference preparation:** composite the accepted RGBA character onto one uniform neutral background; use a fixed canvas and scale with generous clearance around the full anticipated motion. Lock side/profile direction. Padding should be established before video generation, not recovered by independently cropping moving frames.

**Generation:** keep camera locked, full body visible, one character, consistent light, no translation across the frame. Generate one action per clip. For loops, try the same prepared image at first and last frame using the existing last_frame input; this constrains endpoints but does not guarantee smooth cyclic velocity or prevent pauses. For attacks use a neutral start and recovered end only when that fits the intended action; specify one anticipation → strike → recovery with no repeated strikes.

**Master export:** expose the subgraph's decoded video image batch and save lossless PNGs alongside MP4 preview. If that requires awkward subgraph editing, extract from the existing MP4 for the trial; native decoder PNG output is preferable for future masters because it avoids H.264 compression. Do not regenerate new detail by upscaling every frame independently.

**Frame preparation:** choose a useful range/cadence, segment the foreground consistently, and inspect alpha flicker on claws, limb gaps and shell edges. Prefer temporally consistent masks if available; the installed per-image cutout is a fallback that needs per-frame QA. Use one union crop and one fixed scale/pivot across the entire sequence. Never center each frame by its bounding box; that produces foot sliding and artificial body jitter. Distinguish unwanted camera drift from intended body/limb movement before stabilization.

**Game integration:** package reviewed frames as SpriteFrames/AnimatedSprite2D or a spritesheet with timing metadata. Keep animation playback on a visual child; the movement controller owns world translation and collisions. An in-place walk cycle can track movement speed. Attack contact must be tied to an explicit simulation attack phase/event, not an arbitrary generated frame. Jump/fall are separate states, not a walk video played while airborne. Pause/resume and frame selection must not create extra damage events.

## Starting prompt: breaker idle loop

> Locked-off orthographic side-view game animation of the single reference creature facing right. Preserve its exact shell pattern, anatomy, silhouette, colors, scale and screen position. Uniform neutral background and constant lighting. Entire body and claws stay inside the canvas. Feet remain planted on the same ground line; the torso subtly breathes and the forward claw slowly flexes once, then returns to the original resting pose. One gentle complete cycle over the clip, smooth movement across the loop boundary. No walking, foot shuffling, body rotation, camera movement, zoom, cuts, new limbs, particles, shadows changing or other objects. No music or dialogue.

For locomotion replace the action paragraph with one complete in-place stride, clear alternating planted feet and no net body travel. For attack replace it with one distinct windup, forward/down claw strike and recovery, with approximate timings. Keep these as three different clips; do not ask the model to combine them.

## Tool and references

Reproduce extraction to a NEW output directory:

```powershell
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/inspect_animation.py art/side-view/animations/breaker_animation.mp4 art/side-view/animations/breaker-review-new
```

The utility refuses an existing destination to protect reviewed frames. It uses installed PyAV/Pillow; no additional dependencies were installed. No H3 generation or changes to the installed workflow/game were performed in this review.

Official context: [MiniMax H3 model announcement](https://www.minimax.io/blog/minimax-h3). Local graph connections and decoded video are the evidence for the specific findings above; do not confuse the local H3 workflow with older hosted Hailuo API settings.
