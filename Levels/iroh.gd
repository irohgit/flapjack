# =============================================================================
# SequenceRunner
#
# Plays the intro sequence in order, then hands off to gameplay. Each stage is
# instanced as a child, awaited, then freed, so this scene stays loaded and
# owns the flow. Stages know nothing about each other or what comes next.
# =============================================================================

extends Node

@export var splash_scene: PackedScene
@export var cinematic_scene: PackedScene
@export var level_scene: PackedScene

# Untick to skip straight to gameplay while testing.
@export var play_intro := true


func _ready() -> void:
	if play_intro:
		await _run(splash_scene)
		await _run(cinematic_scene)

	# The level stays, so no await and no free.
	add_child(level_scene.instantiate())


# Instances a stage, waits for it to report done, then removes it.
func _run(scene: PackedScene) -> void:
	var stage := scene.instantiate()
	add_child(stage)
	await stage.finished
	stage.queue_free()
	await get_tree().process_frame   # let the free complete before the next stage
