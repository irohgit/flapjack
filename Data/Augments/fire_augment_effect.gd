class_name FireAugmentEffect
extends AugmentEffect

@export var burn_damage_per_tick := 1
@export var burn_tick_count := 2
@export var burn_tick_interval := 0.5
@export var fireball_frames: SpriteFrames
@export var fireball_animation := &"burn"

func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.fire = true
	_projectile.fire_damage_per_tick = burn_damage_per_tick
	_projectile.fire_tick_count = burn_tick_count
	_projectile.fire_tick_interval = burn_tick_interval
	_projectile.sprite_frames_override = fireball_frames
	_projectile.animation_name_override = fireball_animation
