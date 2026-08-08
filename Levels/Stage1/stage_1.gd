extends LevelManager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(scroll_director != null, "Level 1 needs a ScrollDirector")
	assert(enemy_controller != null, "Level 1 needs an EnemyController")
	assert(not enemy_controller.enemy_types.is_empty(), "Level 1 needs an enemy type")
	
	var basic_enemy := enemy_controller.enemy_types[0]
	var first_wave: Array[EnemyData] = [basic_enemy, basic_enemy, basic_enemy, basic_enemy, basic_enemy]
	
	scroll_director.move_to(Vector2(0, -1000))
	
	enemy_controller.spawn_pack(first_wave, Vector2(0, -600), EnemyController.Formation.V_SHAPE)
