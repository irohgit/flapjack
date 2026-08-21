extends Node
# Autoload. Survives scene changes and player death - this is where
# "between runs" state lives, since Player itself gets queue_free()'d.

var banked_gin := 0
var bonus_max_health := 0
var bonus_max_speed := 0.0

func add_gin(amount: int) -> void:
	banked_gin += amount

func spend_coins(amount: int) -> bool:
	if banked_gin < amount:
		return false
	banked_gin -= amount
	return true
