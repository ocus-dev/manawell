# Pump geometry study — 2026-09-06

## Question and method

Can a local matte-clay Img2Img reference produce smoother, less perforated TRELLIS geometry while the original colored concept guides texture synthesis?

Source: [original concept](../generated/pipeline-pump-20260906-211723-a4bb48/concept.png). Clay: [local Krea Img2Img result](pump-clay-055/clay.png), denoise 0.55, seed 9062048. The exact pump-specific prompt and graph are preserved in `pump-clay-055/api.json`. The reusable CLI now defaults to a generic object prompt; reproducing this exact image requires the saved prompt. No ControlNet was used. The result changed some details, so this is not a perfectly geometry-preserving transformation.

All mesh trials use seed 9062048, 1.5 m target height, 12,000-triangle game budget and 2K textures. Shape and texture conditioning share the original background-removal mask. Clay guides shape only; original color guides newly synthesized textures, not an exact projection.

## 512 comparisons

| Variant | Run ID | Prepared triangles | Prepared boundary edges | Interpretation |
|---|---|---:|---:|---|
| Original, legacy cleanup | `pipeline-pump-20260906-211723-a4bb48` | 11,999 | 620 | Existing reference; irregular surfaces remain. |
| Original, no remesh or hole filling | `pump-conservative-20260906-223512-e97fa5` | 11,998 | 8,488 | Severe fragmentation; disabling remeshing is worse. |
| Clay shape, no remesh or hole filling | `pump-clay-shape-20260906-223728-699ae0` | 11,998 | 7,272 | Some boundary reduction relative to the previous row, but visibly torn and distorted; not a successful fix. |
| Original, remesh with inner faces retained | `pump-shell-512-20260906-223928-c44c9b` | 11,991 | 471 | Zero boundaries before Blender reduction, but 1,137 nonmanifold edges at that stage; not a clean topology result. |

Boundary counts are measured after welding seam duplicates to five decimal places in normalized coordinates. They depend on tolerance, can include intentional openings, and are not a hole count or a visual-quality score. Zero boundaries does not prove a watertight manifold. Each run contains `topology-report.json` with the full measurements.

The pre-cleanup original mesh has 5,490,044 triangles and many open/nonmanifold edges. The clay version has 4,776,896 triangles and also has extensive topology problems. Thus defects exist before game import. Cleanup substantially changes the topology; Blender reduction can introduce additional boundaries. This experiment does not isolate every cleanup operation independently.

## Visual evidence

Original with legacy cleanup, matte review:

![Legacy](../generated/pipeline-pump-20260906-211723-a4bb48/review-clay-rear.png)

Original without remeshing:

![Original without remeshing](../generated/pump-conservative-20260906-223512-e97fa5/review-clay-rear.png)

Clay shape without remeshing:

![Clay shape](../generated/pump-clay-shape-20260906-223728-699ae0/review-clay-rear.png)

Original with remeshing and inner faces retained:

![Shell retained](../generated/pump-shell-512-20260906-223928-c44c9b/review-clay-rear.png)

Resetting custom normals on the last prepared mesh did not visibly resolve the defects; see its `review-clay-recomputed-*.png` pair. Both opposite camera views and PBR renders are retained in each run. The labels front/rear identify fixed camera positions, not a semantic orientation inferred from the asset.

## Higher-resolution check

`pump-shell-1024-20260906-224059-b24cef` repeats the original-reference, preserve-shell variant at `1024_cascade`, with the same seed, texture resolution and 12,000-triangle final budget. It completed locally. Its final surfaces remain visibly irregular, and the opposite side still contains invented forms. Increasing generation resolution did not deliver a clear visual improvement at this game budget. This does not rule out a benefit with a different simplification strategy or a larger budget.

The dense output contains 24,260,150 triangles. TRELLIS processing reduces it to 97,016 triangles (12 boundary edges, 1,136 nonmanifold edges under the audit's welding convention); Blender produces 11,986 triangles (457 boundary edges, 1,099 nonmanifold edges). Retaining more input detail alone does not produce a clean reduced shell.

![1024 matte review](../generated/pump-shell-1024-20260906-224059-b24cef/review-clay-rear.png)

![1024 color review](../generated/pump-shell-1024-20260906-224059-b24cef/review-pbr-rear.png)

## Pipeline additions

- `assets.ps1 shape`: resumable local clay Img2Img with configurable prompt, seed and denoise.
- `new --shape-image`: independent geometry reference, original concept still used for textures; dimensions checked before run creation and both source hashes retained.
- `new --cleanup conservative|preserve-shell`: explicit experimental cleanup choices. The legacy default remains unchanged.
- `new --audit-mesh`: retains the dense mesh before TRELLIS cleanup. These files are large.
- `audit_mesh.py` and `blender_review.py`: topology reports and consistent opposite-view PBR/clay renders without modifying the saved asset.

Sixteen inexpensive regression checks pass, including separate shape/texture conditioning, cleanup binding, mismatched image dimensions and changed completed clay output. Existing generated assets and game placements are preserved.

## Recommendation

Do not make clay conversion mandatory based on this example. Use the original concept as the baseline, retain mesh-stage evidence, and inspect the final reduced mesh in neutral lighting. A future constrained Img2Img pass should preserve edges/depth or require a silhouette review; prompt wording alone did not guarantee alignment here. No routine generation step requires Codex, but reference approval and geometry acceptance still need a person.

For this hard-surface pump, the next useful experiment is to clean/reconstruct the shell before aggressive reduction and texture baking, allocating geometry to the housing and pipes rather than retaining problematic interior surfaces. Compare the approximately 100K mesh with the 12K result before spending more time on image prompts. If broad panels still deform, a simple modeled housing and cylindrical pipes may be more economical than repeated generation. None of these trials replaces the game asset or changes production defaults.
