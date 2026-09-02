class_name EnemyDropTableData
extends Resource


@export var table_name: String = "Drops"
## Stable LevelData.level_id values where this table applies. Leave empty to
## make the table apply in every level.
@export var level_ids: PackedStringArray = []
## Each roll independently chooses one weighted pickup or no drop.
@export_range(1, 100, 1, "or_greater") var rolls: int = 1
## Relative to the pickup weights; zero guarantees a pickup when the pool is valid.
@export_range(0.0, 1000.0, 0.01, "or_greater") var no_drop_weight: float = 0.0
@export var drops: Array[WeightedDropData] = []


func applies_to(level_id: StringName) -> bool:
	return level_ids.is_empty() or level_ids.has(String(level_id))
