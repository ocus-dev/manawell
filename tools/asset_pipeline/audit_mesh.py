"""Read-only topology audit. Requires the installed ComfyUI numpy/trimesh packages."""
import argparse
import json
from pathlib import Path
import numpy as np
import trimesh


def audit(path):
    scene = trimesh.load_scene(path)
    mesh = scene.to_mesh()
    # GLB duplicates vertices at UV and normal seams. Weld in normalized space
    # before counting boundaries, so texture seams do not look like holes.
    extent = float(np.max(mesh.extents))
    mesh.vertices = (mesh.vertices - mesh.bounds[0]) / max(extent, 1e-12)
    mesh.merge_vertices(merge_tex=True, merge_norm=True, digits_vertex=5)
    counts = np.bincount(mesh.edges_unique_inverse)
    boundary = mesh.edges_unique[counts == 1]
    lengths = np.linalg.norm(mesh.vertices[boundary[:, 0]] - mesh.vertices[boundary[:, 1]], axis=1)
    return {'file': str(path), 'triangles': len(mesh.faces), 'welded_vertices': len(mesh.vertices),
            'weld_precision': '5 decimal places after longest dimension normalized to 1',
            'boundary_edges': int(len(boundary)), 'boundary_length_relative_to_extent': float(lengths.sum()),
            'nonmanifold_edges': int(np.sum(counts > 2)), 'watertight': bool(mesh.is_watertight),
            'finite_vertices': bool(np.isfinite(mesh.vertices).all()),
            'note': 'Boundaries may include intentional openings. Metrics alone do not measure visual quality.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    reports = [audit(args.directory/name) for name in ('before-cleanup.glb', 'raw.glb', 'prepared.glb') if (args.directory/name).exists()]
    (args.directory/'topology-report.json').write_text(json.dumps(reports, indent=2))
    print(json.dumps(reports, indent=2))
