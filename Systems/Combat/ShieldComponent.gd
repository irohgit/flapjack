class_name ShieldComponent
extends Node

var stacks := 0

signal stacks_changed(current: int)
signal hit_blocked

func add_stack(amount: int = 1) -> void:
	stacks += amount
	stacks_changed.emit(stacks)

# Returns true if a hit was absorbed (caller should skip applying damage).
# Returns false if there was no shield, so the caller should proceed to
# apply damage normally.
func try_block_hit() -> bool:
	if stacks <= 0:
		return false
	stacks -= 1
	stacks_changed.emit(stacks)
	hit_blocked.emit()
	return true

func get_stacks() -> int:
	return stacks
