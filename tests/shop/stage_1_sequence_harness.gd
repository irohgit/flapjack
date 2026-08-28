extends "res://Levels/Stage1/stage_1.gd"

var transition_requested := false
var checkpoint_present_when_transition_requested := false


func run_generated_stage() -> bool:
	return true


func _load_next_stage() -> void:
	checkpoint_present_when_transition_requested = GlobalPlayer.has_checkpoint
	transition_requested = true
