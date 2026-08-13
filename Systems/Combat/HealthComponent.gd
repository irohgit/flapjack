# =============================================================================
# HealthComponent
# Attach as a child of any Area2D that can die.
# This component tracks health and announces changes.
# Listeners connect to the signals and choose their own feedback: the player flashes red, an enemy might puff smoke.
# =============================================================================

class_name HealthComponent
extends Node


@export var max_health := 3

# Invincibility frames ("i-frames"). Seconds of immunity granted after a hit.
#
# Why this exists:
#   Contact damage is a CONTINUOUS state, not a discrete event. The player sits
#   inside a rock's collision shape for maybe half a second. Without a lockout,
#   every repeated damage call during that overlap lands, so at 120 physics
#   ticks per second a single scrape could drain full health in milliseconds.
#
#   It is also a fairness rule. The window gives the player time to steer out of
#   geometry they have already clipped, turning an instant death into a survivable
#   near-miss. Every action game does this.
#
# Note this is a LOCKOUT, not a repeating cycle. Each successful hit restarts it.
#   Sitting inside a hazard for 3s at 1.0s   -> damage at 0.0, 1.0, 2.0
#   Three separate hazards spread over 10s   -> damage on all three
#
# Default 0.0 means no i-frames, which is correct for most things. Only the
# player normally sets this. An enemy taking three cannonballs in three frames is not unfair, so it stays at zero.

@export var invincibility_time := 0.0


var current_health: int


var _invincible_for := 0.0 # Seconds of immunity remaining. Counts down to zero, never negative.


signal health_changed(current: int, maximum: int)
signal damaged
signal died


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	_invincible_for = maxf(_invincible_for - delta, 0.0)


func take_damage(amount: int) -> void:
	if current_health <= 0 or _invincible_for > 0.0:
		return
	_invincible_for = invincibility_time
	# maxi clamps at zero so overkill damage cannot push health negative.
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	damaged.emit()

	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	var old_health := current_health
	# mini clamps at max_health so overheal can't push past the cap.
	current_health = mini(current_health + amount, max_health)
	if current_health != old_health:
		health_changed.emit(current_health, max_health)
	#print("health: ", current_health)

# Stable read API for observers such as UI. UI should listen to health_changed
# for live updates, then use these methods once when it first connects.
func get_current_health() -> int:
	return current_health


func get_max_health() -> int:
	return max_health


# Public read of the private timer. Feedback and HUD code asks through this
# rather than reaching into _invincible_for directly.
func is_invincible() -> bool:
	return _invincible_for > 0.0
