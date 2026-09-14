# Catalog performance fix — 2026-09-13

Base examined: 0842033, integration checkout with unrelated active changes. Scope: campaign_catalog.gd, content_catalog.gd and dedicated probe/cache tests. No gameplay or animation files were overwritten.

Root cause: HUD model construction repeatedly builds content/campaign catalogs. Their new constructors reload and validate the campaign files on every instance. Production calculations also create ContentCatalog instances, multiplying the work.

Change: cache successfully validated default campaign-derived definitions for the process lifetime. Each catalog receives a deep copy, preserving existing mutable-instance behavior. Invalid loads are not cached. Custom campaign roots remain uncached for editor/fixture validation. invalidate_cache() is available on both catalog classes; after changing campaign data in a running tool, invalidate BOTH caches and rebuild its catalog consumers. Existing live runs/instances intentionally retain their current definitions. Restarting the game naturally refreshes all data.

Measured using performance_catalog_probe.gd, headless Godot 4.8-dev4 on this machine, two HUD warmups and 20 iterations per measurement:

| CPU operation | Before ms/call | After ms/call |
|---|---:|---:|
| HUD view-model build | 85.8876 | 1.58085 |
| ContentCatalog constructor | 10.5008 | 0.12165 |
| CampaignCatalog constructor | 10.1498 | 0.1182 |

This is about 98% less CPU time for HUD model construction, not a rendered FPS measurement. Initial cold loading still validates files. GPU/animation rendering was not profiled by this probe.

Checks: cache isolation/invalidation, content catalog, production, campaign state save/restore, LD01 loader and LD02 migration parity completed without unexpected script/assertion failures. Loader intentionally tests malformed JSON. Campaign/loader/migration tests required outside-sandbox access for their isolated fixture files. Content/production tests exit zero on completion but have no textual completion markers; their test lifecycle/output was inspected. No general integration-green claim is made for other currently regressed features.
