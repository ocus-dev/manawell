"""Prepare weapon concept art without publishing runtime content.

The job manifest is deliberately independent of weapon stats or behavior.  A
ComfyUI submission is optional; transparent and corrected-mask inputs are
fully local and preserve source pixels.
"""
import argparse
import hashlib
import json
import shutil
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ROOT = ROOT / "art" / "weapons" / "runs"
STAGES = ("snapshot", "cutout", "prepare", "review")
OUTPUTS = (
    "original.png", "cropped-source.png", "rgba-master.png", "world-sprite.png",
    "square-icon.png", "grip-calibration.json", "review-light.png",
    "review-dark.png", "review-actual-size.png",
)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def stable_hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode("utf-8")).hexdigest()


def write_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def emit(directory, event, **fields):
    record = {"time": datetime.now(timezone.utc).isoformat(), "event": event, **fields}
    with (Path(directory) / "progress.jsonl").open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, sort_keys=True) + "\n")


def settings_for(source, cutout, mask, crop, world_height, icon_size, pivot):
    return {"cutout": cutout, "mask": str(mask) if mask else None, "crop": crop,
            "world_height": world_height, "icon_size": icon_size, "pivot": pivot,
            "source_sha256": digest(source), "mask_sha256": digest(mask) if mask else None}


def new_manifest(job_id, source, settings):
    return {"version": 1, "job_id": job_id, "kind": "weapon-concept-preparation",
            "source": str(Path(source).resolve()), "settings": settings,
            "settings_hash": stable_hash(settings), "status": "new", "stages": {},
            "outputs": {}, "gpu_work": {"submitted": False, "prompt_id": None,
            "reconciliation": "not-required"}}


def load_job(root, job_id):
    if "/" in job_id or "\\" in job_id or ".." in job_id:
        raise ValueError("Use a job ID, not a path.")
    directory = Path(root).resolve() / job_id
    manifest_path = directory / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Unknown weapon job: {job_id}")
    return directory, json.loads(manifest_path.read_text(encoding="utf-8"))


def save(directory, manifest):
    write_json(Path(directory) / "manifest.json", manifest)


def _stage(manifest, name):
    return manifest["stages"].setdefault(name, {"status": "pending", "outputs": {}})


def _complete(directory, manifest, name, names):
    record = _stage(manifest, name)
    record.update(status="complete", outputs={n: digest(Path(directory) / n) for n in names})
    emit(directory, "stage_complete", stage=name, outputs=list(names), progress=stage_progress(name))


def stage_progress(name):
    return {"snapshot": 0.15, "cutout": 0.45, "prepare": 0.75, "review": 1.0}[name]


def _valid_outputs(directory, record):
    return record.get("status") == "complete" and all(
        (Path(directory) / name).is_file() and digest(Path(directory) / name) == value
        for name, value in record.get("outputs", {}).items())


def _reset_derived(directory, manifest):
    for name in OUTPUTS:
        path = Path(directory) / name
        if path.exists():
            path.unlink()
    manifest["stages"] = {}
    manifest["outputs"] = {}
    manifest["status"] = "settings_changed"
    emit(directory, "settings_changed", stale_outputs=list(OUTPUTS))


def _copy_if_new(source, destination):
    if destination.exists():
        if digest(source) != digest(destination):
            raise RuntimeError(f"Refusing to overwrite immutable output: {destination}")
        return
    shutil.copy2(source, destination)


def _alpha_master(directory, manifest):
    source_name = manifest.get("cutout_source", "original.png")
    source = Image.open(Path(directory) / source_name).convert("RGBA")
    settings = manifest["settings"]
    crop = settings.get("crop")
    if crop:
        x, y, width, height = crop
        source = source.crop((x, y, x + width, y + height))
    mask_path = settings.get("mask")
    if settings["cutout"] == "corrected" and mask_path:
        mask = Image.open(mask_path).convert("L")
        if mask.size != source.size:
            raise ValueError("Corrected mask must match the cropped source dimensions.")
        source.putalpha(ImageChops.multiply(source.getchannel("A"), mask))
    elif settings["cutout"] not in ("transparent", "corrected"):
        raise RuntimeError("ComfyUI cutout requires a configured graph and server; resume after reconciliation.")
    alpha = source.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    if not bounds:
        raise ValueError("Source has no visible pixels after mask/crop.")
    cropped = source.crop(bounds)
    cropped.save(Path(directory) / "cropped-source.png")
    source.save(Path(directory) / "rgba-master.png")
    return cropped


def _comfy_cutout(directory, manifest, url):
    sys.path.insert(0, str(ROOT / "tools" / "asset_pipeline"))
    from comfy import Comfy

    client = Comfy(url)
    graph_path = ROOT / "art" / "side-view" / "workflows" / "06_cutout.api.json"
    if not graph_path.is_file():
        raise FileNotFoundError(f"ComfyUI cutout graph not found: {graph_path}")
    graph = json.loads(graph_path.read_text(encoding="utf-8"))
    graph["1"]["inputs"]["image"] = client.upload(
        Path(directory) / "original.png", f"telos-weapon-{manifest['job_id']}.png"
    )
    graph["5"]["inputs"]["filename_prefix"] = f"Telos/Weapons/{manifest['job_id']}/cutout"
    gpu_work = manifest["gpu_work"]
    gpu_work.setdefault("token", f"weapon:{manifest['job_id']}")
    gpu_work["submitted"] = True
    manifest["status"] = "preparing"
    save(directory, manifest)
    try:
        result = client.run(
            graph,
            Path(directory),
            "cutout",
            gpu_work,
            lambda: save(directory, manifest),
            1800,
        )
    except RuntimeError as error:
        if "unknown" in str(error).lower():
            manifest["status"] = "needs_reconciliation"
            gpu_work["reconciliation"] = "unknown-needs-review"
            save(directory, manifest)
        raise
    output_name = "comfy-cutout.png"
    client.download_image(result, "5", Path(directory) / output_name)
    gpu_work["reconciliation"] = "found"
    gpu_work["status"] = "complete"
    manifest["cutout_source"] = output_name
    save(directory, manifest)


def prepare(directory, manifest):
    cropped = _alpha_master(directory, manifest)
    height = manifest["settings"]["world_height"]
    scale = height / cropped.height
    world = cropped.resize((max(1, round(cropped.width * scale)), height), Image.Resampling.LANCZOS)
    world.save(Path(directory) / "world-sprite.png")
    size = manifest["settings"]["icon_size"]
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fit = cropped.copy()
    fit.thumbnail((round(size * 0.9), round(size * 0.9)), Image.Resampling.LANCZOS)
    icon.alpha_composite(fit, ((size - fit.width) // 2, (size - fit.height) // 2))
    icon.save(Path(directory) / "square-icon.png")
    pivot = manifest["settings"]["pivot"]
    write_json(Path(directory) / "grip-calibration.json", {
        "coordinate_system": "top-left pixels; normalized values are relative to cropped-source",
        "pivot_normalized": pivot,
        "pivot_pixels": [pivot[0] * cropped.width, pivot[1] * cropped.height],
        "source_size": list(cropped.size), "world_size": list(world.size),
    })


def review(directory, manifest):
    world = Image.open(Path(directory) / "world-sprite.png").convert("RGBA")
    for name, color in (("review-light.png", (232, 232, 226, 255)), ("review-dark.png", (30, 38, 42, 255))):
        canvas = Image.new("RGBA", world.size, color)
        canvas.alpha_composite(world)
        canvas.convert("RGB").save(Path(directory) / name)
    actual = Image.new("RGBA", world.size, (0, 0, 0, 0))
    actual.alpha_composite(world)
    actual.save(Path(directory) / "review-actual-size.png")


def _reconcile(manifest, find_job):
    token = manifest["gpu_work"].get("token")
    if not token:
        return "not-required"
    if hasattr(find_job, "find_job"):
        find_job = find_job.find_job
    prompt_id = find_job(token)
    if prompt_id:
        manifest["gpu_work"].update(prompt_id=prompt_id, reconciliation="found")
        return "found"
    manifest["gpu_work"]["reconciliation"] = "unknown-needs-review"
    manifest["status"] = "needs_reconciliation"
    return "unknown-needs-review"


def reconcile_submission(root, job_id, find_job):
    directory, manifest = load_job(root, job_id)
    result = _reconcile(manifest, find_job)
    save(directory, manifest)
    emit(directory, "submission_reconciled", result=result)
    return result


def comfy_reconciler(url):
    """Return the existing asset-pipeline client for safe token lookup/submission."""
    sys.path.insert(0, str(ROOT / "tools" / "asset_pipeline"))
    from comfy import Comfy
    client = Comfy(url)
    return client


def run_job(directory, manifest, reconcile=None):
    directory = Path(directory)
    if manifest.get("status") == "complete" and all(_valid_outputs(directory, _stage(manifest, stage)) for stage in STAGES):
        emit(directory, "already_complete", gpu_work=False)
        return manifest
    if manifest.get("status") == "needs_reconciliation":
        if reconcile is None or _reconcile(manifest, reconcile) != "found":
            save(directory, manifest)
            return manifest
    for name in STAGES:
        record = _stage(manifest, name)
        if _valid_outputs(directory, record):
            continue
        emit(directory, "stage_started", stage=name, progress=stage_progress(name) - 0.1)
        if name == "snapshot":
            _copy_if_new(Path(manifest["source"]), directory / "original.png")
            _complete(directory, manifest, name, ("original.png",))
        elif name == "cutout":
            if manifest["settings"]["cutout"] == "comfy" and not manifest.get("cutout_source"):
                if reconcile is None:
                    raise RuntimeError("ComfyUI cutout requires --comfy-url for submission and reconciliation.")
                _comfy_cutout(directory, manifest, reconcile.url)
            _alpha_master(directory, manifest)
            cutout_outputs = ["cropped-source.png", "rgba-master.png"]
            if manifest.get("cutout_source"):
                cutout_outputs.append(manifest["cutout_source"])
            _complete(directory, manifest, name, cutout_outputs)
        elif name == "prepare":
            prepare(directory, manifest)
            _complete(directory, manifest, name, ("world-sprite.png", "square-icon.png", "grip-calibration.json"))
        elif name == "review":
            review(directory, manifest)
            _complete(directory, manifest, name, ("review-light.png", "review-dark.png", "review-actual-size.png"))
        save(directory, manifest)
    manifest["outputs"] = {name: digest(directory / name) for name in OUTPUTS}
    manifest["status"] = "complete"
    emit(directory, "job_complete", progress=1.0, gpu_work=manifest["gpu_work"]["submitted"])
    save(directory, manifest)
    return manifest


def create_or_load(args):
    root = Path(args.root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    source = Path(args.source).resolve()
    if not source.is_file():
        raise FileNotFoundError(f"Source image not found: {source}")
    mask = Path(args.mask).resolve() if args.mask else None
    if mask and not mask.is_file():
        raise FileNotFoundError(f"Corrected mask not found: {mask}")
    crop = [int(v) for v in args.crop.split(",")] if args.crop else None
    if crop and len(crop) != 4:
        raise ValueError("--crop requires x,y,width,height")
    pivot = [float(v) for v in args.pivot.split(",")]
    if len(pivot) != 2 or not all(0 <= value <= 1 for value in pivot):
        raise ValueError("--pivot requires normalized x,y values between 0 and 1")
    settings = settings_for(source, args.cutout, mask, crop, args.world_height, args.icon_size, pivot)
    job_id = args.job_id or (source.stem.lower() + "-" + uuid.uuid4().hex[:10])
    directory = root / job_id
    directory.mkdir(parents=True, exist_ok=True)
    manifest_path = directory / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest["settings_hash"] != stable_hash(settings):
            _reset_derived(directory, manifest)
            manifest.update(source=str(source), settings=settings, settings_hash=stable_hash(settings),
                            gpu_work={"submitted": False, "prompt_id": None, "reconciliation": "not-required"})
    else:
        manifest = new_manifest(job_id, source, settings)
    save(directory, manifest)
    return directory, manifest


def parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--root", default=str(DEFAULT_ROOT))
    common.add_argument("--job-id")
    common.add_argument("--source")
    common.add_argument("--cutout", choices=("transparent", "corrected", "comfy"), default="transparent")
    common.add_argument("--mask")
    common.add_argument("--crop")
    common.add_argument("--world-height", type=int, default=256)
    common.add_argument("--icon-size", type=int, default=256)
    common.add_argument("--pivot", default="0.5,1.0")
    common.add_argument("--comfy-url", help="Local ComfyUI URL used only to reconcile a saved token.")
    cli = argparse.ArgumentParser()
    commands = cli.add_subparsers(dest="command", required=True)
    start = commands.add_parser("start", parents=[common])
    start.set_defaults(action="start")
    resume = commands.add_parser("resume", parents=[common])
    resume.set_defaults(action="resume")
    status = commands.add_parser("status")
    status.add_argument("job_id")
    status.add_argument("--root", default=str(DEFAULT_ROOT))
    status.set_defaults(action="status")
    return cli


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.action == "status":
            _directory, manifest = load_job(args.root, args.job_id)
            print(json.dumps(manifest, indent=2))
            return 0
        if args.action == "start":
            directory, manifest = create_or_load(args)
        else:
            if not args.job_id:
                raise ValueError("resume requires --job-id")
            directory, manifest = load_job(args.root, args.job_id)
        reconcile = comfy_reconciler(args.comfy_url) if args.comfy_url else None
        run_job(directory, manifest, reconcile=reconcile)
        print(json.dumps(manifest, indent=2))
        return 0 if manifest["status"] == "complete" else 2
    except Exception as error:
        if "directory" in locals() and "manifest" in locals():
            manifest["status"] = "blocked"
            manifest["error"] = str(error)
            save(directory, manifest)
            emit(directory, "blocked", message=str(error))
        print(json.dumps({"status": "blocked", "error": str(error)}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
