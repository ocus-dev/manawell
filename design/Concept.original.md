# Mana well is an incremental game built using AI 

The game is built as a fractal of geometric progression systems which are intertwined as they are introduced, that is progression in earlier systems will be gated by progression in the later systems. 

The visual themes should be inspired by

"
Massive retro-futurist powered armor soldier, 1980s Japanese OVA anime aesthetic, brutalist industrial mecha design, oversized proportions, chunky segmented armor, exposed pistons and vents, hand-painted cel animation, thick black ink outlines, hard cel shading, deep painted shadows, saturated red armor, chipped paint and grime, glowing highlights, Japanese military stencil markings, dramatic low-angle shot, extreme foreshortening, smoke and steam in the background, analog film grain, dark industrial sci-fi atmosphere.
"

Incremental game about harvesting mana from cracks in the earth

Core gameplay loop revolves around starting the mana harvesting machine and protecting it as denizens of the region attack, summoned by the smell of the mana. More mana = more difficult monsters till player is overwhelmed. The player determines when to harvest the mana, generally as close as possible to when their health bar is nearing 0, rewards increase the longer they wait. Once they are overwhelmed the state is reset, if the player has not harvested the mana then it is lost.

This is an incremental game that involves a number of stages. The stages are split into two kinds:
- monster stages which test the players hero strength, they are cleared once the player as killed x number of monster
- well stages which feature an environment with a mana crack that the player can install a harvesting machine on and protect according to the logic stated above, eventually players will have mutliple heros which they can leave to guard the machine and automatically collect mana. In this way mana wells at earlier stages + weaker heros can produce passive income for the player.

There will be incremental advancement along the following paths:

Hero (fighting ability development i.e. projectiles, speed, area of effect, statistical advancement i.e. health, amror, damage value )

Mana extraction machine (rate of mana collected, buffs for heros, visual changes, various upgrades that change gameplay)


Game is broken up into levels and acts, an act contains a series of on theme monsters and 2 wells. The second well will produce mana at double the rate.

At first the player will have access to a single playable hero then after discovering the first mana well will get access to more via mana shop.

Mana shop will allow the player to spend mana collected by the machines on, player characters which are obtained via a gotcha like mechanic or upgrades for mana harvesting machines. 

The gotcha mechanic is the addictive part of the game so will need to carefully balance this. To start with heros will just be a single order of magnitude apart statistically ( Stat system tbd) 

The upgrades for the mana harvester should land on a progression tree, with a combination of efficiency improvements, buffs to heros standing in the same level as the machine. This tree will also need to be carefully tuned so that it feels fun to play without the content collapsing into a single optimization path.

The core player loop involves the player working to maximize the rate of mana they are obtaining. As they progress through stages they will get access to richer mana wells. Better heros will be able to defend a well for longer period of time. The longer they hold out the greater the reward multiplier. Each act should introduce a new mechanic and type of mana that way earlier efforts are not devalued. More advanced items in the manashop(harvest progression, higher rate gotcha tickets) will require multiple types of mana from different acts.

Player will need multiple heros to guard mana wells, they can leave heros on a specific stage to continue harvesting mana while they progress through monster stages with their strongest hero.

Technical requirements:

3d graphics, online support to allow player communication/co-op/leaderboards, cheat prevention to make progress meaningful.