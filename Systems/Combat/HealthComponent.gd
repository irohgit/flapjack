class_name HealthComponent
extends Node

# Health values are stored in half-heart units.
const UNITS_PER_HEART := 2

signal health_changed(current: int, maximum: int)
signal shield_changed(current: int)
signal shield_damaged(amount: int)
signal damaged
signal died

@export var max_health := 3
@export var invincibility_time := 0.0

var current_health: int
var shield_points := 0

var _invincibility_remaining := 0.0


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	_invincibility_remaining = maxf(_invincibility_remaining - delta, 0.0)


func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0 or is_invincible():
		return

	_invincibility_remaining = invincibility_time
	var absorbed_damage := mini(shield_points, amount)

	if absorbed_damage > 0:
		shield_points -= absorbed_damage
		shield_changed.emit(shield_points)
		shield_damaged.emit(absorbed_damage)

	var health_damage := amount - absorbed_damage
	if health_damage > 0:
		current_health = maxi(current_health - health_damage, 0)
		health_changed.emit(current_health, max_health)

	damaged.emit()
	if current_health == 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	var previous_health := current_health
	current_health = mini(current_health + amount, max_health)
	if current_health != previous_health:
		health_changed.emit(current_health, max_health)


func add_shield(amount: int) -> void:
	if amount <= 0:
		return

	shield_points += amount
	shield_changed.emit(shield_points)


func set_max_health(new_max: int) -> void:
	max_health = maxi(new_max, 1)
	current_health = max_health
	health_changed.emit(current_health, max_health)


func get_current_health() -> int:
	return current_health


func get_max_health() -> int:
	return max_health


func get_shield_points() -> int:
	return shield_points


func is_invincible() -> bool:
	return _invincibility_remaining > 0.0
