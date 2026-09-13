class_name SoulShot
extends Projectile

@export var strip_sfx: AudioStream
@export var strip_text_colour := Color(0.75, 0.4, 1.0)


## Armour is destroyed outright, all of it. With no armour to take, this
## returns false and the base damage from the ProjectileData applies instead,
## which is why that damage should be set to 1.
func _consume_hit(area: Area2D) -> bool:
	var player := area as Player
	if player == null:
		return false
	if not player.try_strip_armour():
		return false

	if strip_sfx != null:
		Audio.play_sfx(strip_sfx)
	FloatingText.spawn(
		get_parent(),
		player.global_position + Vector2(0.0, -48.0),
		"ARMOUR LOST",
		strip_text_colour
	)
	return true
