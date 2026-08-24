class_name LevelData
extends Resource

@export_group("Playfield")
@export var playfield_size: Vector2 = Vector2(1920.0, 1080.0)


@export_group("Stage")
@export var level_name: String = ""
@export var end_position: Vector2 = Vector2(0, -10000)
@export var spawn_ahead_distance: float = 600.0

@export_group("Encounter Sequence")
@export var encounter_sequence: Array[EncounterData] = []

@export_group("Stage Finale")
@export var finale_trigger_position: Vector2 = Vector2(0, -9000)
@export var finale_spawn_position: Vector2 = Vector2(0, -9600)
@export var finale_pool: Array[WeightedEndEventData] = []

func get_playfield_center() -> Vector2:
	return playfield_size * 0.5
