class_name CreatureAnimation
extends RefCounted

## The MiniMax H3 image-to-video graph and prompt templates the Creature Lab
## submits to ComfyUI. A GDScript port of tools/animation_pipeline/workflows.py
## (same models, sampler, steps, frame rule and node ids), so a take made in
## the lab can also be rerun from its saved API graph in ComfyUI itself.

const UNET := "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
const CLIP := "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
const VIDEO_VAE := "minimax_h3_video_vae_fp16.safetensors"
const AUDIO_VAE := "minimax_h3_audio_vae_fp32.safetensors"
const SAMPLER := "res_multistep"
const SCHEDULER := "simple"
const DEFAULT_STEPS := 15
const DEFAULT_SEED := 234508078907053
const DEFAULT_SECONDS := 3.0
const DEFAULT_SIZE := 576
const SOURCE_FPS := 24.0
## Seeds stay below 2^53 so they survive JSON (numbers are doubles there).
const MAX_SEED := 9007199254740991
const H3_NODE := "MiniMaxH3ImageToVideo"
const CUTOUT_NODE := "Trellis2RemoveBackground"
## Node ids in graph(): decoded frames are saved by 17, the MP4 preview by 16.
const FRAMES_NODE := "17"
const PREVIEW_NODE := "16"
const CUTOUT_OUTPUT_NODE := "5"

## {facing} becomes "left" or "right".
const COMMON := "Locked-off side-view game animation of the single reference creature facing {facing}. Preserve its armor plates, shell pattern, anatomy, silhouette, colors, scale and screen position. Uniform neutral grey background and constant lighting. Entire body, tail and claws stay inside the canvas. No body rotation, camera movement, zoom, cuts, new limbs, particles, changing shadows or other objects. "

const MOTIONS := {
	"idle": "Feet remain planted on the same ground line; the torso subtly breathes and the head and forward claw slowly shift once, then return to the original resting pose. One gentle complete cycle over the clip, smooth movement across the loop boundary. No walking or foot shuffling. No music or dialogue.",
	"walk": "One complete slow in-place walking stride, with alternating planted feet, clear weight transfer and small natural torso motion. Body stays centered with no net forward travel. Return to the initial stride phase by the end with continuous cyclic motion. No attack or claw strike. No music or dialogue.",
	"attack": "One attack only. First quarter: deliberate anticipation, rearing back and raising the forward claw or head. Middle: a distinct forward strike toward the facing direction. Final half: settle and recover to the original resting pose. Feet remain planted; no walking or extra strikes. No impact particles or target objects. No music or dialogue.",
	"windup": "A telegraph before an attack: the creature lowers, draws back and tenses, coiling for a strike, and holds the coiled pose for the final third. No strike is released. Feet remain planted. No particles. No music or dialogue.",
	"hurt": "One flinch: the creature recoils backward from a blow to its front, shudders briefly, then recovers to the original resting pose. Feet stay on the same ground line; no stepping or falling. No blood or particles. No music or dialogue.",
	"death": "The creature is defeated: it staggers, its legs buckle and its body collapses onto the ground line, then lies completely still for the final third. It stays whole and inside the canvas. No blood, gore, particles or dust. No music or dialogue.",
	"spawn": "The creature arrives: it starts low and curled on the ground line, then rises and unfolds into its normal standing resting pose by the end, holding it for the final few frames. No particles or portals. No music or dialogue.",
}

## States whose clip should end on the reference pose (H3 gets the reference
## as its last frame too). Others end somewhere new (lying dead, coiled).
const RETURNS_TO_REST := ["idle", "walk", "attack", "hurt"]
## Looping states; the rest play once (SideViewVisualConfig.LOOPING_STATES).
const LOOPING := ["idle", "walk"]

## The starting prompt for a state.
static func template(state: String, facing: String = "left") -> String:
	var side := "right" if facing == "right" else "left"
	return COMMON.replace("{facing}", side) + str(MOTIONS.get(state, MOTIONS["idle"]))

## H3 supports 17k + 5 frames; rounds up like workflows.frame_count().
static func frame_count(seconds: float) -> int:
	var frames := maxi(5, roundi(seconds * SOURCE_FPS))
	return frames + posmod(5 - frames % 17, 17)

## The ComfyUI API graph. `last` is "" to leave the end free (only when the
## installed H3 node allows it; see ComfyAnimationClient.last_frame_optional).
static func graph(prompt: String, first: String, last: String, size: int, seconds: float, seed: int, prefix: String, steps: int = DEFAULT_STEPS) -> Dictionary:
	var h3 := {"clip": ["4", 0], "vae": ["5", 0], "first_frame": ["1", 0], "prompt": prompt, "width": size, "height": size, "length": frame_count(seconds)}
	var result := {
		"1": _node("LoadImage", {"image": first}),
		"3": _node("UNETLoader", {"unet_name": UNET, "weight_dtype": "default"}),
		"4": _node("CLIPLoader", {"clip_name": CLIP, "type": "minimax", "device": "default"}),
		"5": _node("VAELoader", {"vae_name": VIDEO_VAE}),
		"6": _node("VAELoader", {"vae_name": AUDIO_VAE}),
		"7": _node(H3_NODE, h3),
		"8": _node("RandomNoise", {"noise_seed": seed}),
		"9": _node("KSamplerSelect", {"sampler_name": SAMPLER}),
		"10": _node("BasicScheduler", {"model": ["3", 0], "scheduler": SCHEDULER, "steps": steps, "denoise": 1.0}),
		"11": _node("BasicGuider", {"model": ["3", 0], "conditioning": ["7", 0]}),
		"12": _node("SamplerCustomAdvanced", {"noise": ["8", 0], "guider": ["11", 0], "sampler": ["9", 0], "sigmas": ["10", 0], "latent_image": ["7", 1]}),
		"13": _node("VAEDecode", {"samples": ["12", 0], "vae": ["5", 0]}),
		"14": _node("VAEDecodeAudio", {"samples": ["12", 0], "vae": ["6", 0]}),
		"15": _node("CreateVideo", {"images": ["13", 0], "audio": ["14", 0], "fps": SOURCE_FPS, "bit_depth": 8}),
		"16": _node("SaveVideo", {"video": ["15", 0], "filename_prefix": prefix + "/preview", "format": "mp4", "codec": "auto"}),
		"17": _node("SaveImage", {"images": ["13", 0], "filename_prefix": prefix + "/master"}),
	}
	if not last.is_empty():
		result["2"] = _node("LoadImage", {"image": last})
		h3["last_frame"] = ["2", 0]
	return result

## Trellis 2 background removal for one image (workflows.cutout()).
static func cutout_graph(image: String, prefix: String) -> Dictionary:
	return {
		"1": _node("LoadImage", {"image": image}),
		"2": _node(CUTOUT_NODE, {"image": ["1", 0], "low_vram": true}),
		"3": _node("InvertMask", {"mask": ["2", 1]}),
		"4": _node("JoinImageWithAlpha", {"image": ["1", 0], "alpha": ["3", 0]}),
		"5": _node("SaveImage", {"images": ["4", 0], "filename_prefix": prefix}),
	}

static func random_seed() -> int:
	return (int(randi()) << 21 | int(randi() & 0x1FFFFF)) % MAX_SEED

static func _node(kind: String, inputs: Dictionary) -> Dictionary:
	return {"class_type": kind, "inputs": inputs}
