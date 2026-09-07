# Mana Well — Game Concept

> Working title · Revised September 5, 2026
>
> Expanded design proposal. New mechanics and numerical examples are hypotheses to prototype, not validated balance or fixed production commitments. The original skeleton is preserved in Concept.original.md. Art direction follows visual-style-bible.md.

## 1. High-level vision

**Mana Well is a 3D incremental action-defense game about extracting power from a world that fights back.** Command a heavy industrial suit, install a harvester over a glowing fracture, and defend it as the mana plume attracts increasingly dangerous creatures. Decide when to seal the tank and bank your haul. Another surge could fund your next breakthrough, but defeat costs the unbanked mana. Spend successful harvests on specialized heroes and visibly evolving machinery. Turn conquered wells into automated production sites, then lead a new expedition into richer territory.

The fantasy grows from **one operator protecting a rattling pump** to **a commander running an extraction network**. Active play provides danger, discovery, and exceptional harvests. Automation makes earlier accomplishments continue working for you.

AI-assisted development is a production approach, not the player-facing premise.

## 2. What should be fun?

The central question is: **“Can I survive the next surge, and is its reward worth what I already have?”**

Five design pillars support it:

1. **Readable risk.** Players can see what they stand to earn, what they might lose, and what danger is approaching. Failure should usually mean “I got greedy” or “I need a different build.”
2. **Physical power growth.** Upgrades change weapon patterns, crowd control, and machine behavior. Larger numbers reinforce a visible improvement.
3. **Conquest becomes infrastructure.** A well that once demanded full attention becomes a dependable background operation. Automation rewards mastery.
4. **Specialists remain useful.** Heroes matter for their defensive roles and regional strengths, even after the player recruits someone more powerful.
5. **New layers simplify old work.** Later systems expand decisions while reducing repetitive maintenance.

Support both a short visit to collect income and buy an upgrade, and a longer session of frontier expeditions. Constant attendance should not be necessary to keep the network functional.

## 3. What the game looks and feels like

Use compact 3D arenas with an elevated three-quarter camera. The harvester is the visual anchor, surrounded by readable approach routes and enough space to reposition. Normal combat must clearly show attack windups, machine damage, and escape routes. Reserve dramatic low angles for arrivals and extraction celebrations.

Operators wear massive powered armor: chunky plates, exposed joints, vents, chipped paint, and heavy weapon recoil. The harvester unfolds stabilizers, drives a probe into the crack, and fills armored tanks with increasingly unstable light. Creatures contrast with the industrial equipment through organic silhouettes and movement.

Follow the existing retro-industrial OVA visual bible: painted steel, hard shadow shapes, selective outlines, analog gauges, worn markings, and strong regional palettes. Machine upgrades add visible tanks, cooling stacks, shields, or support drones. Mana glow and enemy attacks need distinct visual identities. Smoke, grain, and screen shake must not obscure warnings and should be adjustable.

### Recommended starting controls

- Move the active hero directly.
- Fire the primary weapon automatically at a sensible target, with an optional priority-target override.
- Use one signature ability and one defensive maneuver.
- Start extraction and issue a clearly accessible harvest command.

This leaves attention for positioning, priority enemies, and risk assessment. Test manual aiming later if necessary; do not assume an incremental audience wants a demanding shooter. In solo play, pausing freezes the active encounter. Background production must use consistent elapsed-time accounting so pausing does not generate extra income.

## 4. The connected gameplay loops

| Scale | Player activity | Payoff |
|---|---|---|
| Moment to moment | Position, intercept threats, use abilities, judge the next surge | Survive and extract more |
| Between expeditions | Bank mana, improve a build, clear a route, commission a well | Reach a new capability or income milestone |
| Across acts | Assign specialists, expand automation, unlock regional technology | Build a stronger network and enter richer territory |

The repeating structure is: earn, invest, overcome a bottleneck, automate the solved task, and encounter a new problem. The original idea of intertwined progression survives, but an unlimited stack of mutually blocking systems would be difficult to understand and balance.

## 5. The extraction encounter

### Preparation

Choose a discovered well, an available hero, and a harvester loadout. Show the region's hazards, enemy tendencies, base yield, and a rough difficulty estimate. Allow free loadout changes outside combat.

### Extraction and defense

Starting the machine begins a fresh run. Mana accumulates in an **unbanked tank** while pressure rises and attracts stronger waves.

Use two health pools:

- **Hero health:** the operator's ability to keep fighting.
- **Harvester integrity:** the machine's ability to contain the mana.

Either reaching zero ends the expedition. Some enemies pursue the hero; others attack the machine. This prevents endlessly running away from being the best defense. Healing and repairs extend survival, but do not reset extraction pressure.

### Surge tiers

Pressure advances through clearly marked surges. Preview the next surge's threat type and reward increase. Early surges introduce swarms; later surges add armored breakers, ranged enemies, or restricted space. Introduce each enemy's behavior before combining it with others.

Mana accumulates between surges, with meaningful reward milestones for completing them. The player weighs an identifiable challenge instead of simply watching health drain. Health, machine integrity, ability cooldowns, the incoming enemy composition, and the next desired purchase all inform the decision.

### Harvesting and failure

The harvest command begins a short, clearly displayed sealing sequence. Test approximately two seconds as a starting point. The payout locks when sealing begins; enemies remain dangerous until it finishes. Sealing cannot be repeatedly canceled to manipulate rewards.

- Successful sealing banks the locked payout and ends the encounter.
- Hero defeat or machine destruction before completion loses that run's unbanked tank.
- Previously banked mana, purchased upgrades, recruited heroes, and commissioned wells remain intact.
- Failure imposes no repair bill or forced waiting period. Restarting is quick.

The delay encourages a safety margin instead of waiting for the last possible frame. Teach it explicitly during the first safe extraction. Compare this against instant harvesting in the prototype and keep the delay only if it adds anticipation without making losses feel like an input trick.

Abandoning forfeits the current tank. A solo interruption should suspend and restore the same encounter where feasible, rather than reroll its threats. Online disconnect rules need a separate specification.

### Discovery and commissioning

Reaching a well discovers it. Completing a modest initial extraction objective commissions it for automation and opens the onward route. Deeper surges are optional mastery challenges. Failure never erases a completed route or commission.

This gives the campaign finishable objectives even though repeat extraction can continue until the player is overwhelmed.

## 6. Illustrative first session

These are pacing targets to test, not fixed timings.

| Approximate point | Experience | Purpose |
|---|---|---|
| First 2 minutes | Cross a short ruined worksite with the starting suit | Learn movement and one combat decision |
| Minutes 2–5 | Deploy at the first crack and complete a guided safe harvest | Understand pressure, the tank, and sealing |
| Minutes 5–8 | Buy a noticeable weapon or pump improvement and attempt a larger harvest | Feel the return on investment |
| Minutes 8–12 | Receive a guaranteed second hero and commission the first well | Discover passive production |
| Minutes 12–20 | Leave a guard behind and approach the richer second well | Understand the long-term loop |

Desired moment: the gauge enters the red, a breaker approaches, and the next surge would fund a wider weapon burst. The player spends a defensive ability to protect the sealing window and escapes with the upgrade money. On a later visit, the wider burst clears the same swarm comfortably.

If an upgrade only changes a displayed number, it needs a stronger gameplay or audiovisual expression.

## 7. Stages and acts

Each act contains a short themed route and **two wells**. A starting layout is an introductory combat stage, a first well, a mechanic-focused combat stage, a second well, and an act guardian. Tune the actual stage count through playtesting.

### Combat stages

Combat stages test hero strength and teach threats that appear during extraction. A kill quota works for an introductory encounter, but should not define every stage. Other objectives might involve defeating a shielded elite, holding a breach briefly, or destroying nests that reinforce enemies.

Avoid objectives that continue after the combat problem is clearly solved. Cleared stages stay cleared. Returning to a well never requires walking the same route again.

### Wells

Retain roughly double base extraction at the second well, paired with greater danger. Twice the base rate need not produce twice the realized income: survival, hero suitability, and attempt duration matter.

The first well remains useful as an automated producer. It does not need an artificial advantage so large that reaching the second well feels pointless.

### Regional variety

Each act introduces one meaningful interaction before combining it with existing threats.

| Proposed act | Setting and mana | New interaction | Player decision |
|---|---|---|---|
| Broken Foundry | Ruined industrial valley; raw mana | Swarms and machine-seeking breakers | Positioning and target priority |
| Drowned Works | Flooded pumping complex; conductive mana | Telegraphs travel along conductive lanes | Repositioning and ranged interruption |
| Rootbound Engines | Overgrown refinery; living mana | Growth blocks firing lanes and supports enemies | Area control and clearing obstructions |

These are examples, not a commitment to build three acts before testing. New regions should change a decision; a palette swap and another currency are insufficient.

## 8. Heroes and power growth

Heroes are operators with distinct armor platforms, signature abilities, defensive tools, and guard specialties.

| Role | Active strength | Guard value | Limitation |
|---|---|---|---|
| Bulwark | Shields the machine and holds a lane | Stable conservative harvesting | Slow elite kills |
| Reaper | Clears clusters with broad attacks | Strong against swarm-heavy wells | Weak against isolated armor |
| Lancer | Removes distant priority targets | Counters ranged-heavy sites | Vulnerable to crowds |
| Engineer | Repairs and deploys support equipment | Improves machine uptime | Lower direct damage |

**Replace the proposed 10× statistical gap between hero rarities.** At comparable investment, that gap would make most recruits irrelevant and turn collection into waiting for a stronger drop.

Large power gains should come from campaign progression. Within a comparable progression band, heroes primarily differ in capabilities, synergies, and modest advantages. Rare heroes can offer distinctive mechanics without invalidating ordinary heroes.

Shared account research gives new recruits a useful baseline. Individual specialization provides commitment without repeating the entire leveling process for every recruit. Early heroes remain upgradeable into later acts.

Combine frequent small statistical purchases with less frequent functional milestones: extra projectiles, piercing, wider suppression, tank protection, or a repair drone. Display upcoming milestones so the player has an understandable goal.

Healing, shielding, and control must not enable endless runs. Pressure continues to escalate, and clearly telegraphed late-run threats eventually exceed every current build.

## 9. Recruitment and the mana shop

Separate reliable advancement from optional randomized recruitment. Players should understand whether they are improving the current plan or obtaining a possible alternative.

Random recruitment can provide surprise and collection goals, but addiction should not be the design objective. The lasting attraction should be discovering what a new hero allows the player to do.

Recommended rules:

- Guarantee the second hero when commissioning the first well. Automation must not depend on luck.
- Provide direct recruitment of essential roles alongside optional randomized recruitment.
- Display random recruitment odds and guarantee progress toward a selected unlock after a bounded number of attempts. Tune the bound with the economy.
- Convert duplicates into a useful, capped upgrade resource. Repeated copies must not be necessary to make the basic kit functional.
- Provide every required campaign capability through predictable play.
- Make repeated recruitment animations skippable and support bulk actions.

Prototype with earned in-game currency only. Monetization is undecided; paid randomized recruitment is not assumed in this concept.

## 10. Harvester progression

Split progression into **permanent engineering research** and **limited loadout modules**. Research improves the baseline. Modules change how an expedition plays. Limited slots preserve tradeoffs even after every module is owned.

| Branch | Example capability | Tradeoff |
|---|---|---|
| Throughput | Overdrive increases extraction | Faster pressure gain |
| Fortification | Integrity and protective fields | Occupies slots that could increase yield |
| Support | Repair pulses or ammunition support | Less extraction specialization |
| Containment | Faster sealing or limited emergency salvage | Lower peak yield potential |

Basic efficiency research should be beneficial without hidden difficulty increases. Explicit overdrive modules may exchange safety for output and must clearly describe that exchange.

Prefer additive bonuses within a family and a small set of clearly named multipliers. Avoid a tree of indistinguishable percentages that requires a spreadsheet to navigate. Aim for recognizable approaches: safe steady harvesting, burst extraction, and extended defensive holds. Their value should vary with enemy patterns and player goals; equal performance everywhere is unnecessary.

Research is account-wide. Modules configure each site or expedition without repeatedly purchasing the same unlock. Improvements should visibly alter the machine at meaningful milestones.

Allow free module swapping and specialization resets outside encounters during the prototype. Add commitment costs only if they create value beyond discouraging experimentation.

## 11. Automated production and crew management

A commissioned well produces income when assigned a compatible guard and equipment. Do not simulate every offscreen monster. Instead calculate a conservative **net mana per minute** from the site, guard, research, and supported extraction policy, then accrue that payout deterministically.

The displayed estimate and actual credited income must use the same rule. Stronger guards and suitable specialties improve rates. Use conservative and balanced policies unlocked through well mastery; extreme surge pushing remains an active activity. Background sites should never silently gamble away hours of income.

Assignment rules:

- A hero has one assignment at a time: expedition, well guard, or reserve.
- Always provide an immediate way to recall a guard and resume active play.
- Recalling stops future production but preserves accrued income, without a punitive timer.
- Playing a well actively replaces its automated operation for the encounter. The same well cannot pay both rates simultaneously.
- Account research automatically updates applicable sites; show the income effect when purchasing it.

Use one network screen for income, assignment, collection, and upgrades. Credit income centrally rather than requiring individual collection clicks. As the network expands, group older wells into regional operations and provide saved assignment presets. Guarantee sufficient crew access for basic coverage as the map grows.

Offline production follows the same rules, with a generous visible storage cap. Test 24 hours initially; wells do not decay after the cap is reached. Online settlement, offline timestamps, and capped accrual must be implemented consistently. Avoid making frequent attendance necessary to preserve basic progress.

Active frontier play should beat the same site's automated rate when played well, but passive production must remain substantial enough that building the network feels worthwhile.

## 12. Economy and progression gates

### Currency structure

Retain regional mana identities without adding an indefinitely growing list of mandatory recipe ingredients.

- Raw mana funds general hero and machine development.
- Regional mana unlocks local research and selected cross-region improvements.
- Typical purchases use at most two resources: a common resource and a relevant regional resource.
- Older regions remain valuable through automation and later bulk refinement into a common engineering resource. Display conversion costs and prevent profitable conversion loops.
- Mature regional inventories live in the network screen rather than crowding combat UI.

Earlier work remains valuable because it keeps producing and its research persists. Every old currency need not remain an ingredient in every future purchase.

### Prevent circular gates

Players must be able to earn entry requirements from content they can already access. Later regional mana may improve earlier machinery, but cannot be required to reach its own source.

Example: Act 1 resources fund the equipment needed to beat its guardian. Act 2 conductive mana then unlocks an optional advanced cooler for the Act 1 pump. That cooler accelerates growth; it is not required to enter Act 2.

### Balance model

Start with an explicit, tunable model:

`base tank = accumulated effective extraction output during the run`

`successful payout = base tank × reached surge multiplier`

`approximate expected rate = success probability × successful payout / full attempt duration`

The last expression is a simplified estimate for a fixed strategy. Actual tuning should measure total banked mana divided by total time across successful and failed attempts, including preparation, sealing, and recovery.

For illustration, a safe strategy banking 120 mana every two minutes earns 60 mana/minute. A risky strategy paying 300 mana on 60% of three-minute attempts also averages 60 mana/minute when failure pays zero. A larger headline reward does not automatically make the risk worthwhile.

Use geometric upgrade costs where appropriate, calibrated against actual earning rates and time to the next meaningful improvement. Do not assume exponential prices, stats, regional yields, and surge multipliers automatically balance each other.

Pressure grows with extraction time and explicit throughput tradeoffs, rather than simply tracking hero power. An upgrade must make previously difficult encounters easier.

### Prestige

Defer global prestige resets until several acts of conquest and automation are demonstrably satisfying. If a reset is added later, it should unlock a different strategy and restore automation quickly. Repeating hours of solved content is not a useful default cost.

## 13. Sources of tedium and proposed corrections

| Risk in the original skeleton | Likely experience | Correction |
|---|---|---|
| Always harvest near zero health | Repeat one timing trick | Surge previews, sealing margin, machine integrity, and varied threats |
| Every stage is a kill quota | Wait for weak enemies to spawn | Short varied objectives and permanently cleared routes |
| Heroes differ by an order of magnitude | Most recruits become dead inventory | Shared baseline and role-based usefulness |
| Every act adds required currency | Maintain an expanding shopping list | Limited recipes, automated supply, and regional consolidation |
| Every well needs attention | Maintenance before meaningful play | Central accounting, presets, and grouped operations |
| Luck gates recruitment strength | Progress stalls on an unlucky streak | Guaranteed roles and direct recruitment |
| Failure deletes too much progress | Avoid risk or stop playing | Lose only the current tank and restart promptly |
| Longer always seems better | Remain in solved runs | Evaluate income per total minute and offer discrete surge challenges |
| Systems repeatedly gate each other | Lose track of the next useful action | Clear dependencies and one visible progression objective |

The test for a system is whether it creates a decision the player wants to make again. More currencies and purchases alone do not accomplish that.

## 14. Interface and feedback

During extraction, prioritize the bankable payout, hero health, machine integrity, pressure, next threat, and sealing status. Keep banked account funds visually distinct from the at-risk tank. Use symbols as well as color.

After an attempt, show banked or lost mana, the failure cause, deepest surge, and a useful next upgrade. Provide quick retry and easy loadout adjustment.

The network screen emphasizes income, stopped sites, available crew, and the current progression objective. Detailed calculations can be inspectable without dominating the main interface.

Sound communicates machine pressure, elite arrivals, and successful sealing. Extraction should feel like a massive mechanism locking safely shut.

## 15. Online direction and scope

3D presentation, communication, cooperative play, leaderboards, and protection of shared progression remain project goals. They should not all be prerequisites for testing the central loop.

Build solo extraction, saving, and a small automated network first. Separate economic rules, combat outcomes, and presentation sufficiently to support future authoritative services. This document does not choose an engine.

A later two-player mode can pair complementary roles around one machine. Scale encounter composition to the party and use personal rewards. Cash-out control requires an explicit agreement mechanism: for example, one player requests harvesting and both confirm. Prototype this separately; disagreement about extraction can turn exciting tension into interpersonal frustration. Specify disconnect and inactivity behavior before release.

For leaderboards, consider fixed-loadout or weekly challenges with separate solo and cooperative categories. Lifetime mana mainly reflects account age. Competitive results and shared economic transactions require server validation; local saves alone cannot prove trustworthy records. If local and verified play coexist, distinguish their competitive eligibility. Cheat prevention reduces abuse rather than guaranteeing its absence.

Public chat also requires moderation and reporting. Friends and invitations are a narrower initial social scope.

## 16. Prototype and validation plan

### First: prove extraction

Build one arena, one hero, one harvester, three enemy types, several surge tiers, harvesting, failure, and a handful of upgrades. Temporary assets are sufficient, but include enough machine animation and sound to test the physical appeal.

Compare instant harvesting with delayed sealing. Observe whether players extract early sometimes, understand failures, and notice the effect of upgrades. Do not add recruitment or a large progression tree to rescue an uninteresting encounter.

### Then: prove the incremental connection

Add a second richer well, a guaranteed second hero, a small upgrade tree, assignments, deterministic offline income, and reliable saving. Verify that leaving a guard behind feels valuable and produces income the player wants to spend.

### Questions for playtesting

- Do players voluntarily retry, with an idea of what to do differently?
- Do threats, loadouts, and purchase goals change extraction choices?
- Are failure causes understandable and losses recoverable?
- Does a functional upgrade noticeably change play?
- Are different builds useful against different enemy patterns?
- Does automation feel earned and reduce repetition?
- Can returning players resume meaningful play without a maintenance session?

Record banked mana per total minute, failure causes, extraction choices, time between meaningful upgrades, and time spent managing wells. Use observation and player explanations alongside metrics; retention alone does not demonstrate enjoyment.

## 17. Open decisions

The recommended starting point is solo-first, direct movement, automatic primary attacks, short risky extractions, guaranteed basic recruitment, and dependable automation.

The largest unresolved choices are target platform, combat intensity, exact run length, monetization, and whether cooperative play is essential to the first public release. Resolve them with the prototype where possible.

The immediate design target is a satisfying sequence: **start the machine, feel the pressure rise, make a deliberate extraction choice, buy something tangible, and return stronger.**
