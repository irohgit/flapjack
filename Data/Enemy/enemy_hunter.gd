class_name EnemyHunter
extends Enemy


@export var patrol_distance := 250.0

var _spawn_position := Vector2.ZERO
var _patrol_direction := 1.0
var _has_spawn_position := false

#func _fire() -> void:
	#var shot := data.projectile_scene.instantiate() as Projectile
	#var shot_data := data.ammo.duplicate() as ProjectileData
	#shot_data.damage = data.projectile_damage
	#shot_data.speed *= data.projectile_speed
	#shot.data = shot_data
	#shot.direction = Vector2.DOWN
#
	## Same parent as this ship, so shots shake with the world.
	#get_parent().add_child(shot)
	#shot.global_position = global_position + Vector2(0, 60)

func _move(delta: float) -> void:
	# Capture this after spawning because the controller assigns the enemy's
	# global position after adding it to the scene tree.
	if not _has_spawn_position:
		_spawn_position = global_position
		_has_spawn_position = true

	# This offset is relative to where the Hunter originally spawned.
	var patrol_offset := Vector2(patrol_distance * _patrol_direction, 0.0)
	var target_position := _spawn_position + patrol_offset
	global_position = global_position.move_toward(
		target_position,
		data.move_speed * delta
	)

	if global_position.is_equal_approx(target_position):
		_patrol_direction *= -1.0
