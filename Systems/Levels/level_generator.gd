class_name LevelGenerator
extends Node

@export var level_data: LevelData

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var generated_plan: Array[GeneratedEncounter] = []

func _ready() -> void:
	# Each stage entry gets a fresh set of encounter chance and pool rolls.
	rng.randomize()

func generate_plan() -> Array[GeneratedEncounter]:
	generated_plan.clear()

	if level_data == null:
		push_error("LevelGenerator has no LevelData")
		return generated_plan

	var travel_direction: float = _get_travel_direction()
	var spawn_ahead_distance: float = absf(level_data.spawn_ahead_distance)
	var centre_x: float = level_data.get_playfield_center().x
	var previous_anchor_y: float = 0.0
	var has_previous_encounter := false

	for index: int in range(level_data.encounter_sequence.size()):
		var encounter_data: EncounterData = level_data.encounter_sequence[index]

		if encounter_data == null:
			push_warning("Encounter %d is empty and will be skipped" % (index + 1))
			continue

		if not _should_run(encounter_data):
			continue

		if not _is_configured(encounter_data, index):
			continue

		var anchor_y: float

		if has_previous_encounter:
			var distance_after_previous: float = maxf(0.0, encounter_data.distance_after_previous)
			anchor_y = previous_anchor_y + travel_direction * distance_after_previous
		else:
			anchor_y = travel_direction * spawn_ahead_distance

		var encounter: GeneratedEncounter = _generate_encounter(encounter_data, anchor_y, centre_x)

		if encounter == null:
			push_error("Encounter %d could not be generated" % (index + 1))
			continue

		# Trigger when the encounter's anchor is spawn_ahead_distance in front of
		# the scroll rig. This makes the first selected encounter immediate.
		var trigger_y: float = anchor_y - travel_direction * spawn_ahead_distance
		encounter.trigger_position = Vector2(centre_x, trigger_y)
		generated_plan.append(encounter)

		previous_anchor_y = anchor_y
		has_previous_encounter = true
	
	_assign_gin(_plan_gin())
	var total_barrels := 0
	for e: GeneratedEncounter in generated_plan:
		total_barrels += e.gin_barrels.size()
	print("GIN PLAN: ", total_barrels, " barrels across ", generated_plan.size(), " encounters")
	return generated_plan

func choose_finale_encounter() -> PackedScene:
	if level_data == null:
		push_error("LevelGenerator has no LevelData")
		return null

	var valid_entries: Array[WeightedEndEventData] = []
	var weights := PackedFloat32Array()

	for entry: WeightedEndEventData in level_data.finale_pool:
		if entry != null and entry.encounter_scene != null and entry.weight > 0.0:
			valid_entries.append(entry)
			weights.append(entry.weight)

	if valid_entries.is_empty():
		push_warning("Finale pool has no valid entries")
		return null

	var index: int = rng.rand_weighted(weights)
	return valid_entries[index].encounter_scene

func _get_travel_direction() -> float:
	return -1.0 if level_data.end_position.y < 0.0 else 1.0

func _should_run(encounter_data: EncounterData) -> bool:
	if encounter_data.chance_to_run <= 0.0:
		return false

	if encounter_data.chance_to_run >= 1.0:
		return true

	return rng.randf() < encounter_data.chance_to_run

func _is_configured(encounter_data: EncounterData, index: int) -> bool:
	match encounter_data.type:
		EncounterData.Type.NORMAL:
			if encounter_data.min_pack_size < 1 or encounter_data.min_pack_size > encounter_data.max_pack_size:
				push_error("Encounter %d has an invalid pack size range" % (index + 1))
				return false

			if not _has_valid_enemies(encounter_data.enemy_pool):
				push_error("Encounter %d has no valid enemies" % (index + 1))
				return false

			if not _has_valid_formations(encounter_data.formation_pool):
				push_error("Encounter %d has no valid formations" % (index + 1))
				return false

		EncounterData.Type.SPECIAL:
			if not _has_valid_special_encounters(encounter_data.special_encounter_pool):
				push_error("Encounter %d has no valid special encounter scenes" % (index + 1))
				return false

		_:
			push_error("Encounter %d has an unknown type" % (index + 1))
			return false
	return true

func _generate_encounter(
	encounter_data: EncounterData,
	anchor_y: float,
	centre_x: float
	) -> GeneratedEncounter:
	var encounter := GeneratedEncounter.new()

	match encounter_data.type:
		EncounterData.Type.NORMAL:
			encounter.type = GeneratedEncounter.Type.NORMAL
			encounter.spawn_position = Vector2(centre_x, anchor_y)
			encounter.formation = _choose_formation(encounter_data.formation_pool)

			var pack_size: int = rng.randi_range(
				encounter_data.min_pack_size,
				encounter_data.max_pack_size
			)

			for unused_index: int in range(pack_size):
				encounter.enemies.append(_choose_enemy(encounter_data.enemy_pool))

		EncounterData.Type.SPECIAL:
			encounter.type = GeneratedEncounter.Type.SPECIAL
			encounter.special_scene = _choose_special_encounter(encounter_data.special_encounter_pool)
			encounter.spawn_from_right = rng.randi_range(0, 1) == 1

		_:
			return null

	return encounter

func _has_valid_enemies(pool: Array[WeightedEnemyData]) -> bool:
	for entry: WeightedEnemyData in pool:
		if entry != null and entry.enemy != null and entry.weight > 0.0:
			return true
	return false

func _has_valid_formations(pool: Array[WeightedFormationData]) -> bool:
	for entry: WeightedFormationData in pool:
		if entry != null and entry.weight > 0.0:
			return true
	return false

func _has_valid_special_encounters(pool: Array[WeightedEncounterData]) -> bool:
	for entry: WeightedEncounterData in pool:
		if entry != null and entry.encounter_scene != null and entry.weight > 0.0:
			return true
	return false

func _choose_enemy(pool: Array[WeightedEnemyData]) -> EnemyData:
	var valid_entries: Array[WeightedEnemyData] = []
	var weights := PackedFloat32Array()

	for entry: WeightedEnemyData in pool:
		if entry != null and entry.enemy != null and entry.weight > 0.0:
			valid_entries.append(entry)
			weights.append(entry.weight)

	var index: int = rng.rand_weighted(weights)
	return valid_entries[index].enemy

func _choose_formation(pool: Array[WeightedFormationData]) -> EnemyController.Formation:
	var valid_entries: Array[WeightedFormationData] = []
	var weights := PackedFloat32Array()

	for entry: WeightedFormationData in pool:
		if entry != null and entry.weight > 0.0:
			valid_entries.append(entry)
			weights.append(entry.weight)

	var index: int = rng.rand_weighted(weights)
	return valid_entries[index].formation

func _choose_special_encounter(pool: Array[WeightedEncounterData]) -> PackedScene:
	var valid_entries: Array[WeightedEncounterData] = []
	var weights := PackedFloat32Array()

	for entry: WeightedEncounterData in pool:
		if entry != null and entry.encounter_scene != null and entry.weight > 0.0:
			valid_entries.append(entry)
			weights.append(entry.weight)

	var index: int = rng.rand_weighted(weights)
	return valid_entries[index].encounter_scene
	
#GIN Functions
func _plan_gin() -> Array[DestructibleData]:
	var barrels: Array[DestructibleData] = []
	if level_data.brown_barrel == null:
		return barrels

	# count the barrel slots this stage actually has
	var normal_count := 0
	for encounter: GeneratedEncounter in generated_plan:
		if encounter.type == GeneratedEncounter.Type.NORMAL:
			normal_count += 1
	var max_slots: int = normal_count * level_data.max_barrels_per_encounter
	if max_slots <= 0:
		push_warning("Gin planned but no normal encounters to hold it")
		return barrels

	var gold_value: int = level_data.gold_value if level_data.gold_barrel != null else 0
	var brown_value: int = maxi(1, level_data.brown_value)
	var richest: int = maxi(gold_value, brown_value)

	# clamp the request to the stage's real ceiling
	var total: int = rng.randi_range(level_data.gin_min, level_data.gin_max)
	var ceiling := max_slots * richest
	if total > ceiling:
		push_warning("Wanted %d gin but stage ceiling is %d (%d slots x %d). Add richer barrels or more encounters." % [total, ceiling, max_slots, richest])
		total = ceiling

	# start with the designer's gold flavour, then add gold if needed to fit the slots
	var gold_count := 0
	if gold_value > 0:
		gold_count = int(round(total * level_data.gold_share)) / gold_value
	var remaining := total - gold_count * gold_value
	var brown_count := int(ceil(float(maxi(remaining, 0)) / float(brown_value)))

	while gold_value > 0 and gold_count + brown_count > max_slots and gold_count * gold_value < total:
		gold_count += 1
		remaining = total - gold_count * gold_value
		brown_count = int(ceil(float(maxi(remaining, 0)) / float(brown_value)))

	brown_count = mini(brown_count, max_slots - gold_count)

	for _i in gold_count:
		barrels.append(level_data.gold_barrel)
	for _i in brown_count:
		barrels.append(level_data.brown_barrel)

	barrels.shuffle()
	return barrels

#This function assigns gin to normal encounters
func _assign_gin(barrels: Array[DestructibleData]) -> void:
	if barrels.is_empty():
		return
	var normals: Array[GeneratedEncounter] = []
	for encounter: GeneratedEncounter in generated_plan:
		if encounter.type == GeneratedEncounter.Type.NORMAL:
			normals.append(encounter)
	if normals.is_empty():
		return
	normals.shuffle()
	for i: int in range(barrels.size()):
		normals[i % normals.size()].gin_barrels.append(barrels[i])
