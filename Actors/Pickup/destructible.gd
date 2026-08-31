class_name Destructible
extends Area2D

@export var data: DestructibleData
@export var idle_anim := "idle" #anim name
@export var hit_anim := "hit"
@export var destruct_anim := "explode"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health: HealthComponent = $HealthComponent
@export var hit_sfx: AudioStream
@export var hit_volume:= -14.0
@export_range(0.0, 0.5, 0.01) var hit_pitchspread:= 0.06
@export_range(0.3, 2.0, 0.01) var hit_basepitch:= 1.0 

func _ready() -> void:
	assert(data != null, "Destructible has no DestructibleData assigned")
	_health.max_health = data.max_health
	_health.current_health = data.max_health
	if data.sprite_frames != null:
		_sprite.sprite_frames = data.sprite_frames
	scale = Vector2.ONE * data.visual_scale
	_play(idle_anim)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_sprite.animation_finished.connect(_on_anim_finished)

func take_damage(amount: int) -> void:
	_health.take_damage(amount)

func _on_damaged() -> void:
	if _sprite.animation != destruct_anim:
		_play(hit_anim)
	Audio.play_sfx(hit_sfx, -18.0, 0.1)
	
func _on_died() -> void:
	#stop collisions and queries
	set_deferred("monitorable", false)   # bullets stop detecting the dying barrel
	set_deferred("monitoring", false)    # and it stops detecting anything
	_drop()
	if _has_anim(destruct_anim):
		_play(destruct_anim)
	else:
		queue_free()

func _on_anim_finished() -> void:
	if _sprite.animation == hit_anim:
		_play(idle_anim)
	elif _sprite.animation == destruct_anim:
		queue_free()

func _drop() -> void:
	if data.drop_scene == null or data.drop_data == null:
		print("drop skipped: drop_scene=", data.drop_scene, " drop_data=", data.drop_data)
		return
	print("dropping gin")
	var pickup := data.drop_scene.instantiate() as WorldPickup
	pickup.data = data.drop_data
	_place_pickup.call_deferred(pickup, global_position)
	
func _place_pickup(pickup: WorldPickup, at: Vector2) -> void:
	get_parent().add_child(pickup)
	pickup.global_position = at
	
func _play(anim: String) -> void:
	if _has_anim(anim):
		_sprite.play(anim)

func _has_anim(anim: String) -> bool:
	return anim != "" and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim)
