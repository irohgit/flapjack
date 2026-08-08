class_name EnemyHunter
extends Enemy


@export var follow_offset := Vector2(0.0, -200.0)

@onready var _player := get_tree().get_first_node_in_group("player") as Player

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
	if not is_instance_valid(_player):
		return

	# The offset is relative to the player. Using global positions keeps this
	# correct even when the player and enemy have different parent nodes.
	var target_position := _player.global_position + follow_offset
	global_position = global_position.move_toward(
		target_position,
		data.move_speed * delta
	)
