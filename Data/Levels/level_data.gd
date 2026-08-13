class_name LevelData
extends Resource

@export_group("Playfield")
@export var playfield_size: Vector2 = Vector2(1920.0, 1080.0)


@export_group("Stage")
@export var level_name: String = ""
@export var end_position: Vector2 = Vector2(0, -10000)
@export var spawn_ahead_distance: float = 600.0

@export_group("Encounters")
@export var min_encounters: int = 8
@export var max_encounters: int = 12
@export var min_special_encounters: int = 1
@export var max_special_encounters: int = 2
@export var min_pack_size: int = 3
@export var max_pack_size: int = 5

@export_range(0.0, 0.35, 0.01) var encounter_spacing_jitter: float = 0.15

@export var guaranteed_normal_start_count: int = 2
@export var finale_buffer: float = 500.0

@export_group("Normal Enemy Pool")
@export var enemy_pool: Array[WeightedEnemyData] = []
@export var formation_pool: Array[WeightedFormationData] = []

@export_group("Special Encounter Pool")
@export var special_encounter_pool: Array[WeightedEncounterData] = []

@export_group("Stage Finale")
@export var finale_trigger_position: Vector2 = Vector2(0, -9000)
@export var finale_spawn_position: Vector2 = Vector2(0, -9600)
@export var finale_pool: Array[WeightedEndEventData] = []

func get_playfield_center() -> Vector2:
	return playfield_size * 0.5
