## Plays one-shot feedback bursts. Knows nothing about specific statuses.
## The cue resource carries every visual decision.
class_name StatusEmission
extends Node2D

## The sprite to flash. Usually the ship's Sprite2D.
@export var flash_target: CanvasItem

@onready var _particles: GPUParticles2D = $Particles

var _flash_tween: Tween = null
var _punch_tween: Tween = null

func play(cue: FeedbackCue) -> void:
	if cue == null:
		return
	_burst(cue)
	if cue.flash_enabled and flash_target != null:
		_flash(cue)
	if cue.punch_enabled and flash_target != null:
		_punch(cue)
	if cue.sound != null:
		Audio.play_sfx(cue.sound, cue.volume_db)
	

func _burst(cue: FeedbackCue) -> void:
	_particles.texture = cue.texture
	_particles.amount = cue.amount
	_particles.lifetime = cue.lifetime
	_particles.modulate = cue.colour
	var material := _particles.process_material as ParticleProcessMaterial
	if material != null:
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = cue.spread_radius
	_particles.restart()


func _flash(cue: FeedbackCue) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_target.modulate = cue.flash_colour
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_target, "modulate", Color.WHITE, cue.flash_time)

func _punch(cue: FeedbackCue) -> void:
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	var node := flash_target as Node2D
	if node == null:
		return
	node.scale = Vector2.ONE
	var half := cue.punch_time * 0.5
	_punch_tween = create_tween()
	_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(node, "scale", Vector2.ONE * cue.punch_scale, half)
	_punch_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_punch_tween.tween_property(node, "scale", Vector2.ONE, half)
