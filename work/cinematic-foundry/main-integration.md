# Main-scene integration

The main scene uses scripts/game/cinematic_presentation_controller.gd, retaining normal encounter startup and persistence. Shared activity, contact-shadow and visual configuration components now live in scripts/game/presentation/. Old experiment paths are compatibility wrappers; the comparison scene uses the same shared implementation.

Enabled in normal play: drill lighting and attached halo, steam, dust, sparks, single-shot and volley muzzle flashes, and actor/drill contact shadows. HUD is excluded from illumination. Transient effects clear with encounter cleanup; animations respect pause. Experiment controls and seeded disposable-account behavior are not included in normal play.

No alternate environment textures were configured in the experiment scene at integration time, so the existing prepared environment remains in use.

Verification passed: main_cinematic_presentation_test, cinematic_foundry_test, fitted_pages_test and inventory_workspace_test. Tests disable saving; the main scene retains persistence by default.
