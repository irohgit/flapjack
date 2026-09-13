class_name DavyJones
extends SailInBoss

@export_group("Skills")
@export var bone_trap_scene: PackedScene
@export var ghost_ship_scene: PackedScene
@export var soul_shot_scene: PackedScene
## Seconds between skills. The cycle is a fixed order, not random.
@export var skill_interval := 4.0
@export var skill_pattern: Array[int] = [0, 2, 1, 2]

@export_group("Spirit Summon")
@export var summon_count := 4
@export var summon_spacing := 120.0
@export var summon_lead := 140.0
@export var max_live_summons := 30 ## Cap number of summons
var _skill_index := 0
var _skill_timer := 0.0
var _spawns: Array[Node2D] = []


func _physics_process(delta: float) -> void:
	super(delta)
	if not has_arrived():
		return

	_skill_timer -= delta
	if _skill_timer > 0.0:
		return
	_skill_timer = skill_interval
	_use_next_skill()


func _use_next_skill() -> void:
	if skill_pattern.is_empty():
		return
	match skill_pattern[_skill_index]:
		0: _bone_catch()
		1: _spirit_summon()
		2: _soul_hit()
	_skill_index = (_skill_index + 1) % skill_pattern.size()


func _bone_catch() -> void:
	if bone_trap_scene == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return

	var trap := bone_trap_scene.instantiate() as Node2D
	get_parent().add_child(trap)
	# Placed where the player is now, not where they are heading. The telegraph
	# window is the escape, so leading the target would remove the counterplay.
	trap.global_position = player.global_position


func _spirit_summon() -> void:
	if ghost_ship_scene == null:
		return

	_prune_spawns()
	var room := max_live_summons - _spawns.size()
	if room <= 0:
		return

	var to_summon := mini(summon_count, room)
	var spread := float(to_summon - 1) * summon_spacing
	var start_x := global_position.x - spread * 0.5

	for index: int in to_summon:
		var ship := ghost_ship_scene.instantiate() as Node2D
		if ship == null:
			continue
		get_parent().add_child(ship)
		ship.global_position = Vector2(
			start_x + float(index) * summon_spacing,
			global_position.y + summon_lead
		)
		_spawns.append(ship)


## Drops references to summons that are already gone, so the array tracks
## living ships rather than growing forever.
func _prune_spawns() -> void:
	var living: Array[Node2D] = []
	for spawn: Node2D in _spawns:
		if is_instance_valid(spawn) and not spawn.is_queued_for_deletion():
			living.append(spawn)
	_spawns = living


func _soul_hit() -> void:
	if soul_shot_scene == null:
		return

	var shot := soul_shot_scene.instantiate() as Projectile
	if shot == null:
		return
	get_parent().add_child(shot)
	shot.global_position = _get_fire_position()
	shot.direction = Vector2.DOWN


## Summoned ghosts do not outlive their summoner.
func _on_died() -> void:
	for spawn: Node2D in _spawns:
		if is_instance_valid(spawn):
			spawn.queue_free()
	_spawns.clear()
	super()
