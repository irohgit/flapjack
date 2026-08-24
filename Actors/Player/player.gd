class_name Player

extends Area2D

#Movement
@export var max_speed := 700.0
@export var responsiveness := 25.0
@export var half_width := 32.0
@export var camera: Camera2D

#Projectile Firing 
@export var weapons: Array[WeaponData]
@export_range(1, 20, 1) var max_weapons := 3
var _weapon_states: Array[WeaponState] = []

@export var coin_count:= 0
@export var gin_count:= 0
@export_range(1, 5, 1) var potion_slot_count := 3

@export var boatTextures: Array[Texture2D]

@onready var _health: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _pickup_range: Area2D = $PickupRange
@onready var _pickup_range_shape: CollisionShape2D = $PickupRange/CollisionShape2D
@onready var _hitbox_shape: CollisionShape2D = $CollisionShape2D

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

#Ship Tier
@export var ship_tiers: Array[ShipTierData] = []
@export var ship_tier := 1:
	set(value):
		ship_tier = clampi(value, 1, 3)
		if is_node_ready():
			_update_hull(_health.current_health, _health.max_health)
			
#BANK MOVEMENT
@export var banks: BankGenerator
@export var bank_push_x := 850.0    # sideways shove out of the sand
@export var bank_push_down := 150.0 # drag downward, like running aground

#Developer Tool
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("kill_self"):
		get_viewport().set_input_as_handled()
		_health.take_damage(9999)
		
func _ready() -> void:
	_potion_slots.resize(potion_slot_count)
	area_entered.connect(_on_area_entered)
	_pickup_range.area_entered.connect(_on_pickup_range_entered)
	_pickup_range.area_exited.connect(_on_pickup_range_exited)
	_health.health_changed.connect(_on_health_changed)
	_apply_tier()
	_update_hull(_health.current_health, _health.max_health)
	_health.damaged.connect(_on_damaged)
	#_health.health_changed.connect(func(c, m): DebugHud.watch("health", "%d/%d" % [c, m]))
	_health.died.connect(_on_died)
	coin_changed.emit(coin_count)
	gin_changed.emit(gin_count)
	
	for weapon in weapons:
		add_weapon(weapon)
func _on_health_changed(current: int, maximum: int) -> void:
	_update_hull(current, maximum)
	
	
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
	
	#Before Processing Movement: Adjust for contact with banks
	#While over sand, shove back out to the water and slightly drag down
	if banks != null and banks.is_on_bank(global_position):
		_external_force.x += banks.bank_push_dir(global_position) * bank_push_x
		_external_force.y += bank_push_down
		
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
	if area.is_in_group("pickup") and area.has_method("attract_to"):
		area.attract_to(self)


func _on_pickup_range_exited(area: Area2D) -> void:
	if area.is_in_group("pickup") and area.has_method("stop_attracting"):
		area.stop_attracting(self)

func set_pickup_radius(radius: float) -> void:
	if _pickup_range_shape.shape is CircleShape2D:
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


func can_add_weapon(weapon: WeaponData) -> bool:
	return weapon != null and _weapon_states.size() < max_weapons


func add_weapon(weapon: WeaponData) -> bool:
	if not can_add_weapon(weapon):
		return false

	_weapon_states.append(WeaponState.new(weapon))
	return true


func get_weapon_count() -> int:
	return _weapon_states.size()


func can_add_augment(augment: AugmentData) -> bool:
	if augment == null or augment.augmentEffect == null:
		return false

	if augment.targetWeapon == null:
		return true

	for state in _weapon_states:
		if state.data == augment.targetWeapon:
			return true

	return false


func add_augment(augment: AugmentData) -> bool:
	if not can_add_augment(augment):
		return false

	if augment.targetWeapon == null:
		augment.augmentEffect.apply_to_player(self)
		return true
		
	for state in _weapon_states:
		if state.data == augment.targetWeapon:
			state.augments.append(augment)
			augment_added.emit(augment)
			return true
	return false


func can_add_potion(potion: PickupData) -> bool:
	return potion != null and potion.is_potion() and has_potion_space()


func has_potion_space() -> bool:
	return _potion_slots.has(null)


func add_potion(potion: PickupData) -> bool:
	if not can_add_potion(potion):
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
	
	
func _update_hull(current: int, maximum: int) -> void:
	var tier_index := clampi(ship_tier - 1, 0, ship_tiers.size() - 1)
	if ship_tiers.is_empty():
		return

	var textures := ship_tiers[tier_index].hull_textures
	if textures.is_empty() or maximum <= 0:
		return

	var ratio := float(current) / float(maximum)
	var index := int((1.0 - ratio) * textures.size())
	index = clampi(index, 0, textures.size() - 1)

	if _sprite.texture != textures[index]:
		_sprite.texture = textures[index]
		

	
func _apply_tier() -> void:
	if ship_tiers.is_empty():
		print("ship_tiers_empty")
		return
	var tier := ship_tiers[clampi(ship_tier - 1, 0, ship_tiers.size() - 1)]
	_sprite.scale = Vector2.ONE * tier.display_scale

	var hit := CapsuleShape2D.new()
	hit.radius = tier.hitbox_radius
	_hitbox_shape.shape = hit

	var pick := CircleShape2D.new()
	pick.radius = tier.pickup_radius
	_pickup_range_shape.shape = pick

	
