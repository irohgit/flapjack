# Enemy loot

Each enemy points to one JSON file through its `loot` property. The file is
a flat array with one object per possible drop.

## Independent chance

```json
[
  {"item": "flapjack:gold_coin", "quantity": 6, "chance": 0.25, "level": "stage_1"}
]
```

This has a 25% chance to spawn six gold-coin pickups. Chance is from `0` to `1`.

## Weighted choice

```json
[
  {"item": "flapjack:gold_coin", "quantity": 1, "weight": 5, "level": "stage_1"},
  {"item": "flapjack:silver_coin", "quantity": 1, "weight": 15, "level": "stage_1"},
  {"item": "none", "weight": 80, "level": "stage_1"}
]
```

Rows with weights are one mutually exclusive pool. Here the result is 5% gold,
15% silver, and 80% no drop. Weights are relative and do not need to total 100.

Most drops need only:

- `item`: the `PickupData.item_id` to spawn.
- `quantity`: copies to spawn after the row wins; defaults to 1.
- `chance` or `weight`: use exactly one.
- `level`: the exact `LevelData.level_id`. Use `"*"` for every level.

Advanced weighted drops may also use:

- `pool`: separates independent weighted choices; defaults to `"default"`.
- `rolls`: independent selections from that pool; defaults to 1. It may appear
  on one row or be repeated, but conflicting values invalidate the pool.
- `item: "none"`: an explicit no-drop weight.

Item IDs are registered automatically from the `PickupData` resources under
`Data/Pickups`; there is no global loot-pool resource to maintain.

Export presets must use **Export all resources in the project** so dynamically
registered pickup resources remain available in exported builds.
