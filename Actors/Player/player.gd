extends Area2D

#Movement
@export var max_speed := 700.0
@export var responsiveness := 25.0
@export var half_width := 32.0

#Projectile Firing 
@export var projectile_scene: PackedScene
@export var ammo: ProjectileData
@export var fire_interval := 0.45

@onready var _health: HealthComponent = $HealthComponent

var velocity := Vector2.ZERO
var _move_intent := Vector2.ZERO

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_health.damaged.connect(_on_damaged)
	_health.health_changed.connect(func(c, m): DebugHud.watch("health", "%d/%d" % [c, m]))
	_health.died.connect(func(): DebugHud.flash("PLAYER DESTROYED"))
	
func _process(_delta: float) -> void:
	_move_intent = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func _physics_process(delta: float) -> void:
	var target := _move_intent * max_speed
	velocity = velocity.lerp(target, 1.0 - exp(-responsiveness * delta))
	position += velocity * delta
	position = Playarea.clamp_to_play_area(position, half_width)
	_fire_timer -= delta
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		_fire()
		_fire_timer = fire_interval
		
func _on_area_entered(area: Area2D) -> void:
	# Overlap Function 
	if area.is_in_group("hazard"):
		take_damage(area.get_contact_damage())

## Camera
func _shake(amount: float) -> void:
	var cams := get_tree().get_nodes_in_group("shake_camera")
	print("cameras found: ", cams.size())
	if not cams.is_empty():
		cams[0].add_trauma(amount)

## Combat
var _fire_timer := 0.0

func _fire() -> void:
	var shot := projectile_scene.instantiate() as Projectile
	shot.data = ammo
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2(0, -40)

func take_damage(amount: int) -> void:
	_health.take_damage(amount)

## Combat Private
func _on_damaged() -> void:
	DebugHud.flash("Player Took 1 Damage")
	_shake(0.4) #Camera Shake
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, _health.invincibility_time)
	
func _on_died() -> void:
	_shake(0.8) #Camera Shake
	DebugHud.flash("PLAYER DESTROYED")
	queue_free()
