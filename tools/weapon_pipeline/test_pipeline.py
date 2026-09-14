import json
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

from tools.weapon_pipeline.pipeline import create_or_load, reconcile_submission, run_job


class Args:
    root = None
    job_id = "fixture"
    source = None
    cutout = "transparent"
    mask = None
    crop = None
    world_height = 100
    icon_size = 64
    pivot = "0.5,0.8"


def make_source(path, alpha=True):
    image = Image.new("RGBA", (240, 160), (245, 245, 245, 255) if not alpha else (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((100, 10, 116, 145), fill=(20, 25, 32, 255))
    draw.polygon(((100, 10), (116, 10), (108, 0)), fill=(20, 25, 32, 255))
    draw.rectangle((78, 48, 138, 64), fill=(190, 40, 40, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def setup():
    temp = Path(tempfile.mkdtemp())
    source = temp / "blade.png"
    make_source(source)
    args = Args()
    args.root, args.source = temp / "runs", str(source)
    return temp, args


def test_alpha_proportions_tip_and_outputs():
    temp, args = setup()
    directory, manifest = create_or_load(args)
    run_job(directory, manifest)
    cropped = Image.open(directory / "cropped-source.png")
    assert cropped.getbbox() == (0, 0, cropped.width, cropped.height)
    assert cropped.height > cropped.width * 2
    assert Image.open(directory / "rgba-master.png").getchannel("A").getbbox()[1] == 0
    assert all((directory / name).is_file() for name in manifest["outputs"])


def test_opaque_fixture_uses_corrected_mask():
    temp = Path(tempfile.mkdtemp())
    source = temp / "opaque.png"
    make_source(source, alpha=False)
    mask = Image.new("L", (240, 160), 0)
    ImageDraw.Draw(mask).rectangle((78, 0, 138, 145), fill=255)
    mask_path = temp / "mask.png"
    mask.save(mask_path)
    args = Args()
    args.root, args.source, args.cutout, args.mask = temp / "runs", str(source), "corrected", str(mask_path)
    directory, manifest = create_or_load(args)
    run_job(directory, manifest)
    alpha = Image.open(directory / "rgba-master.png").getchannel("A")
    assert alpha.getbbox() == (78, 0, 139, 146)


def test_crop_pivot_round_trip_and_settings_invalidation():
    temp, args = setup()
    args.crop, args.pivot = "60,0,120,160", "0.4,0.75"
    directory, manifest = create_or_load(args)
    run_job(directory, manifest)
    calibration = json.loads((directory / "grip-calibration.json").read_text())
    assert calibration["pivot_pixels"] == [calibration["source_size"][0] * 0.4, calibration["source_size"][1] * 0.75]
    args.world_height = 120
    directory, changed = create_or_load(args)
    assert changed["status"] == "settings_changed"
    assert not (directory / "world-sprite.png").exists()


def test_completed_job_is_idempotent_and_does_no_gpu_work():
    _temp, args = setup()
    directory, manifest = create_or_load(args)
    run_job(directory, manifest)
    before = (directory / "progress.jsonl").read_text()
    run_job(directory, manifest)
    after = (directory / "progress.jsonl").read_text()
    assert manifest["gpu_work"]["submitted"] is False
    assert after.count('"event": "stage_started"') == before.count('"event": "stage_started"')


def test_unknown_submission_never_resubmits():
    temp, args = setup()
    directory, manifest = create_or_load(args)
    manifest["status"] = "needs_reconciliation"
    manifest["gpu_work"] = {"submitted": True, "token": "unknown", "prompt_id": None}
    (directory / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    assert reconcile_submission(args.root, args.job_id, lambda _token: None) == "unknown-needs-review"
    _directory, loaded = create_or_load(args)
    assert loaded["status"] == "needs_reconciliation"


def test_interrupted_job_resumes_from_durable_stage():
    _temp, args = setup()
    directory, manifest = create_or_load(args)
    run_job(directory, manifest)
    (directory / "review-dark.png").unlink()
    manifest["status"] = "interrupted"
    run_job(directory, manifest)
    assert manifest["status"] == "complete"
    assert (directory / "review-dark.png").is_file()
