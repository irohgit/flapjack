## An ordinary enemy that fires a fan instead of a single shot. The texture,
## health and fire rate all come from its EnemyData as usual, so one script
## serves any ship that should shoot wide.
class_name CerberusEnemy
extends Enemy

@export_range(1, 12, 1) var shot_count := 3
@export var spread_degrees := 50.0
## Rotates the whole fan. 0 is straight down, 180 fires backwards.
@export var fan_centre := 0.0


func _fire() -> Projectile:
	_fire_fan(_get_fire_position(), shot_count, spread_degrees, fan_centre)
	return null
