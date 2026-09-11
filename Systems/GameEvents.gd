extends Node


signal enemy_died(world_position: Vector2, enemy_data: Resource)
signal boss_defeated(world_position: Vector2)
signal boss_health_changed(current: int, maximum: int)
signal boss_name_changed(boss_name: String)
signal player_died(retry_scene_path: String)
signal gin_requested(entry: int, at: Vector2, barrel_data: DestructibleData)
