# 2D art handoff

## Current presentation contract

- Logical canvas: 1280x720, uniformly scaled at larger viewports; fixed side view.
- Ground contact: authoritative actor center uses the lane baseline near y=540. Decorative body height, muzzle height, and projectile trail height never change hit tests.
- Intended sprite scale: hero and standard enemies occupy roughly 32-64 logical pixels in height; the harvester is a dominant central silhouette approximately 220 logical pixels wide.
- Viewing angle: orthographic side-on profile with no camera orbit, zoom, scrolling, or parallax.
- Draw order: distant gantries and stacks, floor and service walkway, harvester body/mechanism, actors and projectiles, then HUD/menus in the CanvasLayer.
- Functional accents: charcoal/steel infrastructure, muted green-gray surroundings, cyan instrumentation/friendly fire, yellow machine and hazard details, red danger, restrained violet for ranged threats.

## Existing procedural scope

The active scene already supplies gantries, stacks, a central animated harvester, service walkway, role-specific procedural silhouettes, entry/windup warnings, friendly and hostile projectile colors, dash and pulse feedback, and machine damage feedback. Future art should replace individual primitives behind the same ownership and ground-coordinate contract, not add a second scene or simulation path.

## Bounded future asset list

1. Hero sprite sheet with left/right facing and dash pose.
2. Pursuer, breaker, and ranged sprite sheets with warning/windup frames.
3. Harvester mechanical detail and extraction/sealing animation frames.
4. Small friendly/hostile projectile trail variants.
5. Two well palette variants using the existing site IDs.
6. A limited set of background gantry/stack modules.

No assets are generated or downloaded by card 56. Sprite production must preserve the fixed lane, visible entry zones, readable warnings, and nonblocking actor behavior.
