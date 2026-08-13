class_name StageEventData
extends Resource


enum EventType {
	ENEMY_PACK,
	BUTCHERBIRD_WAVE
}


@export_group("Event")

@export var event_type: EventType = EventType.ENEMY_PACK
@export var trigger_position: Vector2 = Vector2.ZERO
@export var spawn_position: Vector2 = Vector2.ZERO


@export_group("Enemy Pack")
@export var enemies: Array[EnemyData] = []
@export var formation: EnemyController.Formation

@export_group("Butcherbird Wave")
@export var bird_data: PatternButcherBirdData
@export var bird_count: int = 3
@export var warning_duration: float = 1.0
@export var min_spawn_interval: float = 0.8
@export var max_spawn_interval: float = 1.2
@export var flip_horizontal: bool = false

#TODO - Chasing Enemy (Frogs)
