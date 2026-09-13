# M01/M02 verification

Eight tests passed in `tools/world_map/test_maps.py`: valid 3/5/1 route, duplicate IDs, cycles, duplicate well references, invalid coordinates, path endpoints and real reference-latent wiring. `verify_delivery.py` checked both native/API pairs against installed node/model schemas and link structure, plus all three candidate manifests, source/master/layout hashes and master dimensions.

Three serial local ComfyUI concept jobs completed successfully:

| Candidate | Seed | Comfy prompt ID |
|---|---|---|
| A_valley | 9073101 | 24283d58-5479-4662-bcdf-53e890d6b12d |
| B_coast | 9073102 | 03890a9e-6479-41cd-b7a6-df0a19ed7c42 |
| C_terraces | 9073103 | fc05f185-1159-4b8c-bcd7-28be1c50189a |

Models: `krea2_turbo_fp8_scaled.safetensors`, `qwen3vl_4b_fp8_scaled.safetensors` (krea2 encoder), `qwen_image_vae.safetensors`. Render: 1536×864, 8 steps, Euler/simple, CFG 1. Each candidate retains exact graph, model parameters, history, token and output hashes. Master preparation is uniform 4/3 Lanczos to 2048×1152; no cropping, stretching or generative upscaling. No corrective fourth render was used.

Source/overlay art visually inspected; candidate-specific route revisions align destination/wells with generated landmarks. Nine markers and labels are visible at 1280×720 without overlap. Connectors remain diagrammatic in places, not literal walkable routes. A best fits established Foundry continuity; B offers open sea but shifts toward Drowned Works; C emphasizes ascent but repeats excavation forms. None is selected or approved.

Two native graphs installed in ComfyUI `Telos_WorldMap`; existing workflows and game source were not modified by this work. Reference revision has a genuine LoadImage/ImageScale/VAEEncode connection to KSampler and adjustable denoise. It was structurally validated, not generation-tested in this batch. Exact geography preservation is not guaranteed. No manual ComfyUI canvas interaction test performed.

No runtime imports, controller/save changes or interactive campaign implementation. M03 design review and approval remain pending. No claims about runtime hit targets or UI interaction are made from static overlays.
