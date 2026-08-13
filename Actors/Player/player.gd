class_name Player

extends Area2D

#Movement
@export var max_speed := 700.0
@export var responsiveness := 25.0
@export var half_width := 32.0
@export var camera: Camera2D

#Projectile Firing 
@export var coin_count:= 0
@export var weapons: Array[WeaponData]
var _weapon_states: Array[WeaponState] = []

@onready var _health: HealthComponent = $HealthComponent
@onready var _shield: ShieldComponent = $ShieldComponent

signal coin_changed(amount: int)
signal augment_added(augment: AugmentData)

var velocity := Vector2.ZERO
var _move_intent := Vector2.ZERO
var _external_force := Vector2.ZERO

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_health.damaged.connect(_on_damaged)
	#_health.health_changed.connect(func(c, m): DebugHud.watch("health", "%d/%d" % [c, m]))
	_health.died.connect(func(): DebugHud.flash("PLAYER DESTROYED"))
	coin_changed.emit(coin_count)
	
	for weapon in weapons:
		_weapon_states.append(WeaponState.new(weapon))
	
func _process(_delta: float) -> void:
	_move_intent = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func _physics_process(delta: float) -> void:
	var target := _move_intent * max_speed
	velocity = velocity.lerp(target, 1.0 - exp(-responsiveness * delta))
	position += (velocity + _external_force) * delta
	position = _clamp_to_camera(position)
	_external_force = Vector2.ZERO
	_update_weapons(delta)
	
func _clamp_to_camera(pos: Vector2) -> Vector2:
	var camera_center = camera.get_screen_center_position()
	var view_size = camera.get_viewport_rect().size
	var margin: float = 0.0
	
	var left = camera_center.x - view_size.x * 0.5
	var right = camera_center.x + view_size.x * 0.5
	var top = camera_center.y - view_size.y * 0.5
	var bottom = camera_center.y + view_size.y * 0.5

	return Vector2(
		clampf(pos.x, left + margin, right - margin),
		clampf(pos.y, top + margin, bottom - margin)
	)
		
func _on_area_entered(area: Area2D) -> void:
	# Overlap Function 
	if area.is_in_group("hazard"):
		take_damage(area.get_contact_damage())
	if area.is_in_group("pickup") and area.has_method("collect"):
		area.collect(self)

## Camera
func _shake(amount: float) -> void:
	var cams := get_tree().get_nodes_in_group("shake_camera")
	#print("cameras found: ", cams.size())
	if not cams.is_empty():
		cams[0].add_trauma(amount)

## Collected item
func _add_coins(amount: int):
	coin_count += amount
	coin_changed.emit(coin_count)

func add_augment(augment: AugmentData) -> bool:
	for state in _weapon_states:
		if state.data == augment.targetWeapon:
			state.augments.append(augment)
			augment_added.emit(augment)
			return true
	return false

## Combat
func _update_weapons(delta: float) -> void:
	var shoot_pressed := Input.is_action_pressed("shoot")
	
	for state in _weapon_states:
		state.cooldown -= delta
		var should_fire := shoot_pressed
		
		if should_fire and state.cooldown <= 0.0 and state.data.weaponType == WeaponData.WeaponType.ACTIVE:
			state.data.weaponBehaviour.fire($".", state)
			
			state.cooldown += maxf(state.data.firerate, 0.001)
			
		elif not should_fire and state.data.weaponType == WeaponData.WeaponType.ACTIVE and state.cooldown < 0.0:
			state.cooldown = 0.0
			
		if state.data.weaponType == WeaponData.WeaponType.PASSIVE && state.cooldown <= 0.0:
			state.data.weaponBehaviour.fire($".", state)
			state.cooldown += maxf(state.data.firerate, 0.001)
		elif not should_fire and state.data.weaponType == WeaponData.WeaponType.PASSIVE and state.cooldown < 0.0:
			state.cooldown = 0.0

#Wind
func apply_wind_force(force: Vector2) -> void:
	_external_force += force

func take_damage(amount: int) -> void:
	if _shield.try_block_hit():
		#DebugHud.flash("Shield absorbed hit")
		return
	_health.take_damage(amount)

func add_shield(amount: int) -> bool:
	_shield.add_stack(amount)
	return true
	
func get_shield_component() -> ShieldComponent:
	return _shield
	
func heal(amount: int) -> void:
	_health.heal(amount)

func get_health_component() -> HealthComponent:
	return _health

## Combat Private
func _on_damaged() -> void:
	#DebugHud.flash("Player Took 1 Damage")
	_shake(0.4) #Camera Shake
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, _health.invincibility_time)
	
func _on_died() -> void:
	_shake(0.8) #Camera Shake
	DebugHud.flash("PLAYER DESTROYED")
	queue_free()
