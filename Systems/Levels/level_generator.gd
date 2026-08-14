class_name LevelGenerator
extends Node

@export var level_data: LevelData

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var generated_plan: Array[GeneratedEncounter] = []

func _ready() -> void:
	if level_data == null:
		push_error("LevelGenerator has no LevelData")
		return
	generate_test_plan()

func generate_plan() -> Array[GeneratedEncounter]:
	generated_plan.clear()

	if level_data == null:
		push_error("LevelGenerator has no LevelData")
		return generated_plan

	if level_data.enemy_pool.is_empty():
		push_error("Enemy pool is empty")
		return generated_plan

	if level_data.formation_pool.is_empty():
		push_error("Formation pool is empty")
		return generated_plan

	var encounter_count: int = rng.randi_range(level_data.min_encounters, level_data.max_encounters)

	var eligible_special_slots: int = maxi(0, encounter_count - level_data.guaranteed_normal_start_count)
	var max_specials: int = mini(level_data.max_special_encounters, eligible_special_slots)
	var min_specials: int = mini(level_data.min_special_encounters, max_specials)

	var special_count: int = 0

	if max_specials > 0:
		special_count = rng.randi_range(min_specials, max_specials)

	var special_slots: Array[int] = []

	while special_slots.size() < special_count:
		var slot: int = rng.randi_range(level_data.guaranteed_normal_start_count, encounter_count - 1)

		if not special_slots.has(slot):
			special_slots.append(slot)

	var last_allowed_y: float = level_data.finale_trigger_position.y + level_data.finale_buffer
	var available_distance: float = absf(last_allowed_y)
	var average_spacing: float = available_distance / float(encounter_count)
	var jitter_amount: float = average_spacing * level_data.encounter_spacing_jitter

	var centre_x: float = level_data.get_playfield_center().x

	for i: int in range(encounter_count):
		var base_y: float = -average_spacing * float(i + 1)
		var jitter: float = 0.0

		if i < encounter_count - 1:
			jitter = rng.randf_range(-jitter_amount, jitter_amount)

		var spawn_y: float = base_y + jitter
		var trigger_y: float = spawn_y + level_data.spawn_ahead_distance

		var encounter := GeneratedEncounter.new()

		encounter.trigger_position = Vector2(centre_x, trigger_y)

		if special_slots.has(i):
			encounter.type = GeneratedEncounter.Type.SPECIAL
			encounter.special_scene = choose_special_encounter()
			encounter.spawn_from_right = rng.randi_range(0, 1) == 1
			# Special encounter appears in the current gameplay window.

		else:
			encounter.type = GeneratedEncounter.Type.NORMAL
			encounter.spawn_position = Vector2(centre_x, spawn_y)
			encounter.formation = choose_formation()

			var pack_size: int = rng.randi_range(level_data.min_pack_size, level_data.max_pack_size)

			for j: int in range(pack_size):
				encounter.enemies.append(choose_enemy())

		generated_plan.append(encounter)

	return generated_plan

func generate_test_plan() -> void:
	if level_data.enemy_pool.is_empty():
		push_error("Enemy pool is empty")
		return

	if level_data.formation_pool.is_empty():
		push_error("Formation pool is empty")
		return

	var encounter_count: int = rng.randi_range(level_data.min_encounters, level_data.max_encounters)

	# Work out how many special encounter slots are allowed.
	var eligible_special_slots: int = maxi(0, encounter_count - level_data.guaranteed_normal_start_count)
	var max_specials: int = mini(level_data.max_special_encounters, eligible_special_slots)
	var min_specials: int = mini(level_data.min_special_encounters, max_specials)

	var special_count: int = 0

	if max_specials > 0:
		special_count = rng.randi_range(min_specials, max_specials)

	# Randomly choose which later encounter slots will be special.
	var special_slots: Array[int] = []

	while special_slots.size() < special_count:
		var slot: int = rng.randi_range(level_data.guaranteed_normal_start_count, encounter_count - 1)

		if not special_slots.has(slot):
			special_slots.append(slot)

	# Work out the usable procedural section of the stage.
	var last_allowed_y: float = level_data.finale_trigger_position.y + level_data.finale_buffer
	var available_distance: float = absf(last_allowed_y)

	# Spread encounters across the entire procedural section.
	var average_spacing: float = available_distance / float(encounter_count)
	var jitter_amount: float = average_spacing * level_data.encounter_spacing_jitter

	print("")
	print("========== GENERATED ", level_data.level_name, " ==========")
	print("Total encounters: ", encounter_count)
	print("Special encounters: ", special_count)
	print("Average encounter spacing: ", roundi(average_spacing))
	print("Finale reserve begins around Y: ", roundi(last_allowed_y))

	for i: int in range(encounter_count):
		var base_y: float = -average_spacing * float(i + 1)
		var jitter: float = 0.0

		# Keep the final encounter anchored at the procedural boundary.
		if i < encounter_count - 1:
			jitter = rng.randf_range(-jitter_amount, jitter_amount)

		var encounter_y: float = base_y + jitter

		if special_slots.has(i):
			print_special_encounter(i, encounter_y)
		else:
			print_normal_encounter(i, encounter_y)

	print("---------- FINALE ----------")
	print("Finale Trigger | Y: ", roundi(level_data.finale_trigger_position.y))
	print("============================")
	print("")
	
func print_normal_encounter(index: int, y_position: float) -> void:
	var formation: EnemyController.Formation = choose_formation()
	var pack_size: int = rng.randi_range(level_data.min_pack_size, level_data.max_pack_size)

	var enemies: Array[EnemyData] = []
	var enemy_names: Array[String] = []

	for i: int in range(pack_size):
		var enemy: EnemyData = choose_enemy()
		enemies.append(enemy)
		enemy_names.append(enemy.resource_path.get_file())

	print("Encounter ", index + 1, " | Y: ", roundi(y_position), " | NORMAL | Enemies: ", enemy_names, " | Formation: ", formation)

func print_special_encounter(index: int, y_position: float) -> void:
	if level_data.special_encounter_pool.is_empty():
		print("Encounter ", index + 1, " | Y: ", roundi(y_position), " | SPECIAL - BUT POOL IS EMPTY")
		return

	var scene: PackedScene = choose_special_encounter()
	print("Encounter ", index + 1, " | Y: ", roundi(y_position), " | SPECIAL | Scene: ", scene.resource_path.get_file())


func choose_enemy() -> EnemyData:
	var weights: PackedFloat32Array = PackedFloat32Array()

	for entry: WeightedEnemyData in level_data.enemy_pool:
		weights.append(entry.weight)

	var index: int = rng.rand_weighted(weights)
	return level_data.enemy_pool[index].enemy


func choose_formation() -> EnemyController.Formation:
	var weights: PackedFloat32Array = PackedFloat32Array()

	for entry: WeightedFormationData in level_data.formation_pool:
		weights.append(entry.weight)

	var index: int = rng.rand_weighted(weights)
	return level_data.formation_pool[index].formation


func choose_special_encounter() -> PackedScene:
	var weights: PackedFloat32Array = PackedFloat32Array()

	for entry: WeightedEncounterData in level_data.special_encounter_pool:
		weights.append(entry.weight)

	var index: int = rng.rand_weighted(weights)
	return level_data.special_encounter_pool[index].encounter_scene
	
func choose_finale_encounter() -> PackedScene:
	if level_data.finale_pool.is_empty():
		push_warning("Finale pool is empty")
		return null

	var weights: PackedFloat32Array = PackedFloat32Array()

	for entry: WeightedEndEventData in level_data.finale_pool:
		weights.append(entry.weight)

	var index: int = rng.rand_weighted(weights)
	return level_data.finale_pool[index].encounter_scene
