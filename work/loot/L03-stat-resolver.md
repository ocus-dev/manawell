# L03 — Shared hero and equipment stat resolution
Owner: Luna. Depends on L02.

Implement a pure resolved-stat layer using the approved D02 composition rules. Consume current research outputs rather than duplicating research math. Inputs: hero baseline, equipped instance rolls, research and existing policies. Outputs: typed effective stats and a source breakdown usable by runtime and preview.

Include comparison of replacing one slot, preserving the other two. Apply exact units, affix caps and rounding from approved tables. Display raw rates independently of attack intervals. Keep generic modifiers separate from weapon/ability IDs.

Acceptance: no-equipment equivalence to the approved baseline; flat-plus-percent example, armor/resistance examples, active mining cadence, cap behavior, empty slots, duplicate-base instances, order independence of additive modifiers and immutable inputs. Cover both heroes and fully researched bounds. Build fixtures for D03 enumeration. Do not hook partial stats into combat or design new affixes. Record results and stop.
