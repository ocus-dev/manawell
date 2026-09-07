# 08 — Player abilities

Dependencies: 07. Status is tracked in ../README.md.

## Read first

Player movement, health routing, enemy damage API. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Add a dash and radial defensive pulse.

## Implement

Implement Space dash and Q pulse with the compact spec values. Dash respects collision and only prevents hero damage while active. Pulse damages each living enemy in radius once; it does not heal or stop pressure. Add cooldown indicators and simple primitive visual feedback. Store ability state explicitly for later serialization.

## Acceptance checks

Dash cannot cross boundaries or the machine. Hero damage is prevented only during dash; machine remains vulnerable. Pulse hits in-range enemies once. Cooldowns freeze while paused and reset on retry. Inputs during terminal phases do nothing.

## Stop boundary

No skill tree, extra abilities, particle packages, or complicated animation.

## Completion note

Implemented explicit hero ability state in `prototype/scripts/game/player.gd`: Space dash with collision-respecting movement and temporary hero-only damage immunity, plus Q radial pulse with one hit per living enemy in radius. Added balance constants, cooldown HUD indicators, primitive pulse feedback, controller input/phase gating, and damage routing through `Hero.receive_damage` for melee and ranged threats. Retry resets ability state.

Checks run with `Godot_v4.8-dev4_win64_console.exe --headless`: bootstrap, arena movement, run state, encounter, melee, automatic weapon, surges/ranged, player abilities, and main-scene startup all exited 0 with no reported errors. Remaining limitation: dash and pulse visuals are intentionally primitive prototype geometry.

