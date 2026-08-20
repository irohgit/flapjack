class_name Player

extends Area2D

#Movement
@export var max_speed := 700.0
@export var responsiveness := 25.0
@export var half_width := 32.0
@export var camera: Camera2D

#Projectile Firing 
@export var weapons: Array[WeaponData]
var _weapon_states: Array[WeaponState] = []

@export var coin_count:= 0
@export var gin_count:= 0
@export_range(1, 5, 1) var potion_slot_count := 3

@onready var _health: HealthComponent = $HealthComponent

@onready var _pickup_range: Area2D = $PickupRange
@onready var _pickup_range_shape: CollisionShape2D = $PickupRange/CollisionShape2D

signal coin_changed(amount: int)
signal gin_changed(amount: int)
signal augment_added(augment: AugmentData)
signal pickup_collected(pickup: PickupData)
signal potion_inventory_changed
signal potion_selection_changed(index: int)

var velocity := Vector2.ZERO
var _move_intent := Vector2.ZERO
var _external_force := Vector2.ZERO
var _is_dead := false
var _potion_slots: Array[PickupData] = []
var _selected_potion_slot := 0

#SFX
@export var cannon_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var death_sfx: AudioStream

func _ready() -> void:
	_potion_slots.resize(potion_slot_count)
	area_entered.connect(_on_area_entered)
	_pickup_range.area_entered.connect(_on_pickup_range_entered)
	_health.damaged.connect(_on_damaged)
	#_health.health_changed.connect(func(c, m): DebugHud.watch("health", "%d/%d" % [c, m]))
	_health.died.connect(_on_died)
	coin_changed.emit(coin_count)
	gin_changed.emit(gin_count)
	
	for weapon in weapons:
		_weapon_states.append(WeaponState.new(weapon))
	
func _process(_delta: float) -> void:
	_move_intent = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	if Input.is_action_just_pressed("potion_previous"):
		select_potion_slot(_selected_potion_slot - 1)
	if Input.is_action_just_pressed("potion_next"):
		select_potion_slot(_selected_potion_slot + 1)
	if Input.is_action_just_pressed("drink_potion"):
		drink_selected_potion()

func _physics_process(delta: float) -> void:
	var target := _move_intent * max_speed
	velocity = velocity.lerp(target, 1.0 - exp(-responsiveness * delta))
	position += (velocity + _external_force) * delta
	position = _clamp_to_camera(position)
	_external_force = Vector2.ZERO
	_update_weapons(delta)
	
func _clamp_to_camera(pos: Vector2) -> Vector2:
	var camera_center_global: Vector2 = camera.get_screen_center_position()
	var camera_center_local: Vector2 = get_parent().to_local(camera_center_global)

	var view_size: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var margin: float = half_width

	var left: float = camera_center_local.x - view_size.x * 0.5
	var right: float = camera_center_local.x + view_size.x * 0.5
	var top: float = camera_center_local.y - view_size.y * 0.5
	var bottom: float = camera_center_local.y + view_size.y * 0.5

	return Vector2(
		clampf(pos.x, left + margin, right - margin),
		clampf(pos.y, top + margin, bottom - margin)
	)
		
func _on_area_entered(area: Area2D) -> void:
	# Overlap Function 
	if area.is_in_group("hazard"):
		take_damage(area.get_contact_damage())

func _on_pickup_range_entered(area: Area2D) -> void:
	if area.is_in_group("pickup") and area.has_method("collect"):
		area.collect(self)

func set_pickup_radius(radius: float) -> void:
	print("set_pickup_radius called with: ", radius)
	print("shape type: ", _pickup_range_shape.shape)
	if _pickup_range_shape.shape is CircleShape2D:
		print("radius after set: ", (_pickup_range_shape.shape as CircleShape2D).radius)
		(_pickup_range_shape.shape as CircleShape2D).radius = radius

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

func _add_gin(amount: int):
	gin_count += amount
	gin_changed.emit(gin_count)

func add_augment(augment: AugmentData) -> bool:
	if augment.targetWeapon == null:
		augment.augmentEffect.apply_to_player(self)
		return true
		
	for state in _weapon_states:
		if state.data == augment.targetWeapon:
			state.augments.append(augment)
			augment_added.emit(augment)
			return true
	return false


func add_potion(potion: PickupData) -> bool:
	if potion == null or not potion.is_potion():
		return false

	for index in range(_potion_slots.size()):
		if _potion_slots[index] == null:
			_potion_slots[index] = potion
			potion_inventory_changed.emit()
			return true

	return false


func select_potion_slot(index: int) -> void:
	if _potion_slots.is_empty():
		return

	var wrapped_index := posmod(index, _potion_slots.size())
	if wrapped_index == _selected_potion_slot:
		return

	_selected_potion_slot = wrapped_index
	potion_selection_changed.emit(_selected_potion_slot)


func drink_selected_potion() -> bool:
	var potion := get_potion_in_slot(_selected_potion_slot)
	if potion == null:
		return false

	match potion.pickup_type:
		PickupData.PickupType.HEALTH:
			if _health.get_current_health() >= _health.get_max_health():
				return false
			_health.heal(potion.heal_amount)
		PickupData.PickupType.SHIELD:
			_health.add_shield(potion.shield_amount)
		_:
			return false

	_potion_slots[_selected_potion_slot] = null
	potion_inventory_changed.emit()
	return true


func get_potion_slot_count() -> int:
	return _potion_slots.size()


func get_potion_in_slot(index: int) -> PickupData:
	if index < 0 or index >= _potion_slots.size():
		return null
	return _potion_slots[index]


func get_selected_potion_slot() -> int:
	return _selected_potion_slot

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
	_health.take_damage(amount)

func add_shield(amount: int) -> bool:
	_health.add_shield(amount)
	return true
	
func heal(amount: int) -> void:
	_health.heal(amount)

func get_health_component() -> HealthComponent:
	return _health

## Combat Private
func _on_damaged() -> void:
	Audio.play_sfx(hit_sfx, 0.0)
	DebugHud.flash("Player Took Damage")
	_shake(0.4) #Camera Shake
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, _health.invincibility_time)
	
func _on_died() -> void:
	Audio.play_sfx(death_sfx, 0.0)
	if _is_dead:
		return
	_is_dead = true
	MetaProgress.add_gin(gin_count)
	set_process(false)
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_shake(0.8) #Camera Shake
	DebugHud.flash("PLAYER DESTROYED")
	GameEvents.player_died.emit(_get_retry_scene_path())
	queue_free()


func _get_retry_scene_path() -> String:
	# Use the nearest instanced stage, not an outer sequence wrapper such as Iroh.
	var ancestor := get_parent()
	while ancestor != null:
		if not ancestor.scene_file_path.is_empty():
			return ancestor.scene_file_path
		ancestor = ancestor.get_parent()

	var current_scene := get_tree().current_scene
	return current_scene.scene_file_path if current_scene != null else ""
