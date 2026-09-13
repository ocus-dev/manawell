# L07 — Loot inventory and character sheet
Owner: Luna. Depends on L06.

Extend the persistent inventory panel; never recreate item controls every HUD refresh. Show instance icons/fallbacks, name, rarity text plus color, item level, equipped hero, locked/New state and actual rolls. Two copies of one base must remain separately selectable. Filter by slot/rarity, sort by recent/name/item level, and provide scrolling or paging within the 100-item limit.

Add hero selection, three equipment slots and replace/unequip actions. Show current → preview effective stats with source breakdown from L03, including capped/no-effect bonuses and conditional monster-family effects. Explain why another hero's item or an active-run change is unavailable. No single 'power score' that hides tradeoffs.

Add inspect, lock and explicit named-item discard confirmation for unequipped/unlocked items. Display capacity before expeditions. Use compact nonmodal drop toasts with rarity text and icon; throttle/aggregate bursts. Results list the run's items and offer navigation to Inventory. Explain that collected items are kept even if extraction fails. No inert equip controls or verbose development notes in product UI.

Acceptance: real mouse clicks across HUD refresh, keyboard focus, duplicate bases, equip comparison correctness, full inventory, discarded selection, filters, 100 items, and screenshot checks at 1280×720 and 1920×1080. Save-enabled checks use isolated test accounts. Record results and stop.
