# Startup operations layout repair — 2026-09-07

The operations screen selected a stacked layout below 1500 logical pixels, but the active game uses a 1280×720 logical canvas even at 1920×1080. Unwrapped guard instructions inflated minimum widths; a plain Control between the scroll container and its content prevented correct overflow measurement. A separately positioned Settings button overlapped the wallet.

Replaced manual scroll/content sizing with native MarginContainer/VBoxContainer layout; enabled side-by-side layout at supported logical widths; made well cards expand equally; wrapped guard and upgrade text; kept Settings in the header's own container. Compact operations-only spacing keeps startup content on screen. Loadout descriptions now have inward margins and enough height to wrap inside their buttons.

Added `prototype/tests/operations_layout_test.gd`, using the real main scene with persistence disabled. It checks both physical window sizes with the configured logical scale, column/start/settings bounds, no startup scrolling, wallet overlap, and loadout text containment. Optional `--capture-layout` writes actual rendered viewport screenshots under this directory.

Verified actual OpenGL runtime captures at 1280×720 and 1920×1080: `operations-layout-1280.png` and `operations-layout-1920.png`. All 22 active tests passed using `prototype/run_tests.ps1` with the installed Godot console executable. The first sandboxed suite could not write save fixtures; the unrestricted rerun passed. No real save reset or gameplay/balance change was made. This verification covers startup layout and existing automated click-routing coverage, not a new full manual campaign playtest.
