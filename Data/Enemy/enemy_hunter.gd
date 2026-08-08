class_name EnemyHunter
extends Enemy

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
	position = position.move_toward(Vector2(0, 50), delta)
