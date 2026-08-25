class_name EncounterData
extends Resource


enum Type {
	NORMAL,
	SPECIAL,
}


@export_group("Encounter")
## NORMAL entries use their enemy and formation pools. SPECIAL entries choose a
## camera-relative scene from their special encounter pool.
@export var type: Type = Type.NORMAL
## Zero never runs, while one always runs. The roll happens when the stage loads.
@export_range(0.0, 1.0, 0.01) var chance_to_run: float = 1.0
## Distance along the stage from the previous encounter that actually ran.
## The first encounter that runs uses LevelData.spawn_ahead_distance instead.
@export_range(0.0, 10000.0, 1.0, "or_greater") var distance_after_previous: float = 500.0


@export_group("Normal Encounter")
@export_range(1, 100, 1, "or_greater") var min_pack_size: int = 3
@export_range(1, 100, 1, "or_greater") var max_pack_size: int = 5
@export var enemy_pool: Array[WeightedEnemyData] = []
@export var formation_pool: Array[WeightedFormationData] = []


@export_group("Special Encounter")
@export var special_encounter_pool: Array[WeightedEncounterData] = []
