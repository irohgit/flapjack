extends LevelManager


const FIRST_CAMERA_POSITION := Vector2(0, -100)
const FIRST_WAVE_POSITION := Vector2(960, 100)
const SECOND_CAMERA_POSITION := Vector2(0, -300)
const SECOND_WAVE_POSITION := Vector2(960, -100)


func _ready() -> void:
	assert(scroll_director != null, "Level 0 needs a ScrollDirector")
	assert(enemy_controller != null, "Level 0 needs an EnemyController")
	assert(not enemy_controller.enemy_types.is_empty(), "Level 0 needs an enemy type")

	var basic_enemy := enemy_controller.enemy_types[0]
	var first_wave: Array[EnemyData] = [basic_enemy]
	var second_wave: Array[EnemyData] = [basic_enemy, basic_enemy]

	# Move to the first encounter, then spawn its wave.
	scroll_director.move_to(FIRST_CAMERA_POSITION)
	await wait_until(
		func() -> bool:
			return scroll_director.has_reached(FIRST_CAMERA_POSITION)
	)
	enemy_controller.spawn_pack(first_wave, FIRST_WAVE_POSITION)

	# Wait for the first wave to be cleared.
	await wait_until(
		func() -> bool:
			return not enemy_controller.has_active_enemies()
	)

	# These two actions begin together.
	scroll_director.move_to(SECOND_CAMERA_POSITION)
	enemy_controller.spawn_pack(second_wave, SECOND_WAVE_POSITION)

	# Wait for both conditions at the same time.
	await wait_until(
		func() -> bool:
			return (
				scroll_director.has_reached(SECOND_CAMERA_POSITION)
				and not enemy_controller.has_active_enemies()
			)
	)

	sequence_completed.emit()
