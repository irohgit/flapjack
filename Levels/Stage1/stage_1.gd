extends LevelManager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(scroll_director != null, "Level 1 needs a ScrollDirector")
	assert(enemy_controller != null, "Level 1 needs an EnemyController")
	assert(not enemy_controller.enemy_types.is_empty(), "Level 1 needs an enemy type")
	
	var basic_enemy := enemy_controller.enemy_types[0]
	var hunter := enemy_controller.enemy_types[1]
	var first_wave: Array[EnemyData] = [basic_enemy, basic_enemy, hunter, basic_enemy, basic_enemy]
	
	scroll_director.move_to(Vector2(0, -10000))
	await wait_until(func() -> bool:
		return scroll_director.has_reached(Vector2(0, 0))
		)
	enemy_controller.spawn_pack(first_wave, Vector2(0, -600), EnemyController.Formation.V_SHAPE)
	
	await wait_until(func() -> bool:
		return scroll_director.has_reached(Vector2(0, -600))
		)
	enemy_controller.spawn_pack(first_wave, Vector2(0, -1200), EnemyController.Formation.LINE)
	
	await wait_until(func() -> bool:
		return scroll_director.has_reached(Vector2(0, -1200))
		)
	enemy_controller.spawn_pack(first_wave, Vector2(0, -1600), EnemyController.Formation.CIRCLE)
	
	await wait_until(func() -> bool:
		return scroll_director.has_reached(Vector2(0, -1600))
		)
	enemy_controller.spawn_pack(first_wave, Vector2(0, -2000), EnemyController.Formation.GRID)
