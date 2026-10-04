class_name GameFlow
extends RefCounted

## Hand-off between scenes for the gameplay loop.
##   New Game  -> main.tscn, which starts the tutorial straight away
##   Continue  -> main.tscn (operations)
## The Hero Roster screen (scenes/hero_hub.tscn) is parked: its files are kept
## for later, but nothing opens it.

static var start_tutorial := false
## PLAY with an existing profile: resume the run in progress if there is one,
## otherwise go to the tutorial until it has been beaten.
static var play_requested := false

## Dev spawn preview (Dev Encyclopedia > Level spawns > Preview): the level to
## open and the spawn settings being edited. The preview never saves.
static var preview_level_id := ""
static var preview_profile: Dictionary = {}
## Home (the main city): the hero shown there, and set when leaving Home so
## main.tscn opens on the map page.
static var home_hero_id := "hero_1"
static var return_to_map := false
## Set when a preview ends, so the title screen reopens the spawn editor there.
static var reopen_spawn_editor_level := ""
