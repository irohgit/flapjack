extends Area2D

#Movement
@export var max_speed := 700.0
@export var responsiveness := 25.0
@export var half_width := 32.0

#Projectile Firing 
@export var projectile_scene: PackedScene
@export var coin_count:= 0
@export var weapons: Array[WeaponData]
var _weapon_states: Array[WeaponState] = []

@onready var _health: HealthComponent = $HealthComponent

var velocity := Vector2.ZERO
var _move_intent := Vector2.ZERO

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_health.damaged.connect(_on_damaged)
	_health.health_changed.connect(func(c, m): DebugHud.watch("health", "%d/%d" % [c, m]))
	_health.died.connect(func(): DebugHud.flash("PLAYER DESTROYED"))
	
	for weapon in weapons:
		_weapon_states.append(WeaponState.new(weapon))
	
func _process(_delta: float) -> void:
	_move_intent = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func _physics_process(delta: float) -> void:
	var target := _move_intent * max_speed
	velocity = velocity.lerp(target, 1.0 - exp(-responsiveness * delta))
	position += velocity * delta
	position = Playarea.clamp_to_play_area(position, half_width)
	_update_weapons(delta)
		
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

## Collected item
func _add_coins(amount: int):
	coin_count += amount
	print("Coins:", coin_count)

## Combat
func _update_weapons(delta: float) -> void:
	var shoot_pressed := Input.is_action_pressed("shoot")
	
	for state in _weapon_states:
		state.cooldown -= delta
		var should_fire := shoot_pressed
		
		if should_fire and state.cooldown <= 0.0 and state.data.weaponType == WeaponData.WeaponType.ACTIVE:
			state.data.weaponBehaviour.fire($".", state.data)
			
			state.cooldown += maxf(state.data.firerate, 0.001)
			
		elif not should_fire and state.data.weaponType == WeaponData.WeaponType.ACTIVE and state.cooldown < 0.0:
			state.cooldown = 0.0
			
		if state.data.weaponType == WeaponData.WeaponType.PASSIVE && state.cooldown <= 0.0:
			state.data.weaponBehaviour.fire($".", state.data)
			state.cooldown += maxf(state.data.firerate, 0.001)
		elif not should_fire and state.data.weaponType == WeaponData.WeaponType.PASSIVE and state.cooldown < 0.0:
			state.cooldown = 0.0

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


class WeaponState:
	var data: WeaponData
	var cooldown := 0.0
	
	func _init(weapon_data: WeaponData) -> void:
		data = weapon_data
