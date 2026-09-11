class_name Player

extends Area2D

enum PurchaseResult {
	SUCCESS,
	INVALID_ITEM,
	NOT_ENOUGH_COINS,
	ALREADY_OWNED,
	CANNOT_ACCEPT,
}

var _developermode:= false
#Movement
@export var max_speed := 700.0
@export var responsiveness := 25.0
@export var half_width := 32.0
@export var camera: Camera2D

#Projectile Firing 
@export var starting_weapons: Array[WeaponData]
@export_range(1, 20, 1) var max_weapons := 3
var _weapon_states: Array[WeaponState] = []
var _player_augments: Array[AugmentData] = []

@export var coin_count:= 0
@export var gin_count:= 0
@export_range(1, 5, 1) var potion_slot_count := 3



#@export var boatTextures: Array[Texture2D]

@onready var _health: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _pickup_range: Area2D = $PickupRange
@onready var _pickup_range_shape: CollisionShape2D = $PickupRange/CollisionShape2D
@onready var _hitbox_shape: CollisionShape2D = $CollisionShape2D
@onready var _status_effects: StatusEffectComponent = $StatusEffectComponent


signal coin_changed(amount: int)
signal gin_changed(amount: int)
signal augment_added(augment: AugmentData)
signal pickup_collected(pickup: PickupData)
signal potion_inventory_changed
signal potion_selection_changed(index: int)
signal health_full
signal exited_play_area
signal potion_drunk(potion: PotionData)

var velocity := Vector2.ZERO
var _move_intent := Vector2.ZERO
var _external_force := Vector2.ZERO
var _is_dead := false
var _potion_slots: Array[PotionData] = []
var _selected_potion_slot := 0
var _can_exit_forward := false
var _has_exited_play_area := false
var _purchase_in_progress := false
var _scripted := false
var _can_fire := true
var _can_switch_potion := true
var _can_drink_potion := true

#SFX
@export var cannon_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var death_sfx: AudioStream

#VFX
const WAKE_DEADZONE := 0.15

@onready var _wake: AnimatedSprite2D = $Wake

#Ship Tier
@export_range(0.5, 5.0, 0.05) var wake_overhang := 2.4 #2.4 works with skiff,
@export_range(0.5, 5.0, 0.05) var wake_length := 1.5:
	set(value):
		wake_length = value
		if is_node_ready():
			_fit_wake_to_hull()
@export var ship_tiers: Array[ShipTierData] = []
@export var ship_tier := 1:
	set(value):
		ship_tier = clampi(value, 1, 3)
		if is_node_ready():
			_update_hull(_health.current_health, _health.max_health)
			#_fit_wake_to_hull()
var _current_tier: ShipTierData
@export var move_threshold := 5.0 
var _tier_has_mast := false
@onready var _masts: Node2D = $Masts

#BANK MOVEMENT
@export var banks: BankPainter
@export var bank_push_x := 850.0    # sideways shove out of the sand
@export var bank_push_down := 150.0 # drag downward, like running aground

#GOD MODE
var _god_mode := false
var _normal_weapon_data: Array[WeaponData] = []

@onready var _emission: StatusEmission = $StatusEmission


#Developer Tools
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	#1. Kill self instantly
	if event.is_action_pressed("kill_self"):
		get_viewport().set_input_as_handled()
		_health.take_damage(9999)

	#2. Toggle developer mode
	if event.is_action_pressed("developer_mode"):
		_developermode = not _developermode
		DebugHud.flash("DEV MODE %s" % ("ON" if _developermode else "OFF"))

	#3. God mode, gated behind developer mode
	if _developermode and event.is_action_pressed("god_mode"):
		_god_mode = not _god_mode
		if _god_mode:
			_health.current_health = _health.max_health
			_normal_weapon_data.clear()
			for state: WeaponState in _weapon_states:
				_normal_weapon_data.append(state.data)
				var buffed: WeaponData = state.data.duplicate()
				buffed.damage = 999
				if buffed.weaponProjectile != null:
					var shot: ProjectileData = buffed.weaponProjectile.duplicate()
					shot.damage = 999
					buffed.weaponProjectile = shot
				state.data = buffed
		else:
			for index: int in _weapon_states.size():
				if index < _normal_weapon_data.size():
					_weapon_states[index].data = _normal_weapon_data[index]
			_normal_weapon_data.clear()
		DebugHud.flash("GOD MODE %s" % ("ON" if _god_mode else "OFF"))
		
func _ready() -> void:
	_apply_meta_upgrades()
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
	if not _status_effects.effect_started.is_connected(_on_effect_started):
		_status_effects.effect_started.connect(_on_effect_started)
	var restored_from_checkpoint := GlobalPlayer.restore_checkpoint(self)
	if not restored_from_checkpoint:
		for weapon in starting_weapons:
			add_weapon(weapon)
		_emit_run_state_changed()

	gin_changed.emit(gin_count)
	_fit_wake_to_hull()

func _on_effect_started(effect_id: StringName) -> void:
	var data := _status_effects.get_effect_data(effect_id)
	if data != null:
		_emission.play(data.cue)
		
func _apply_meta_upgrades() -> void:
	match MetaProgress.boat_tier:
		MetaProgress.BoatTier.SKIFF:    ship_tier = 1
		MetaProgress.BoatTier.SCHOONER: ship_tier = 2
		MetaProgress.BoatTier.GALLEON:  ship_tier = 3
	max_speed += MetaProgress.get_speed_bonus()
	max_weapons += int(MetaProgress.get_weapon_slot_bonus())
	var bonus_health := int(MetaProgress.get_health_bonus())
	if bonus_health > 0:
		_health.set_max_health(_health.max_health + bonus_health)

func _on_health_changed(current: int, maximum: int) -> void:
	_update_hull(current, maximum)
	
	
func _process(_delta: float) -> void:
	if _scripted: #stop normal player process to run an visual entry script for the ship
		return
	_move_intent = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if _status_effects.has_flag(StatusEffectData.FLAG_REVERSE_CONTROLS):
		_move_intent *= -1.0

	if Input.is_action_just_pressed("potion_previous"):
		select_potion_slot(_selected_potion_slot - 1)
	if Input.is_action_just_pressed("potion_next"):
		select_potion_slot(_selected_potion_slot + 1)
	if Input.is_action_just_pressed("drink_potion"):
		drink_selected_potion()
		
func _physics_process(delta: float) -> void:

	#if banks != null:
		#DebugHud.watch("bank", banks.debug_line(global_position))
	var movement_speed := _status_effects.get_modified_value(
		StatusEffectData.STAT_MOVEMENT_SPEED,
		max_speed
	)
	var target := _move_intent * movement_speed
	velocity = velocity.lerp(target, 1.0 - exp(-responsiveness * delta))
		
	#Before Processing Movement: Adjust for contact with banks
	#While over sand, shove back out to the water and slightly drag down
	if banks != null and banks.is_on_bank(global_position):
		_external_force.x += banks.bank_push_dir(global_position) * bank_push_x
		_external_force.y += bank_push_down
	if _scripted:
		_update_masts()
		_update_wake()
		return
	position += (velocity + _external_force) * delta
	position = _clamp_to_camera(position)
	_check_for_forward_exit()
	_external_force = Vector2.ZERO
	_update_weapons(delta)
	#DebugHud.flash(str(velocity))
	_update_masts()
	_update_wake()
	
	
func _clamp_to_camera(pos: Vector2) -> Vector2:
	var camera_center_global: Vector2 = camera.get_screen_center_position()
	var camera_center_local: Vector2 = get_parent().to_local(camera_center_global)

	var view_size: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var margin: float = half_width

	var left: float = camera_center_local.x - view_size.x * 0.5
	var right: float = camera_center_local.x + view_size.x * 0.5
	var top: float = camera_center_local.y - view_size.y * 0.5
	var bottom: float = camera_center_local.y + view_size.y * 0.5
	var minimum_y := -INF if _can_exit_forward else top + margin

	return Vector2(
		clampf(pos.x, left + margin, right - margin),
		clampf(pos.y, minimum_y, bottom - margin)
	)


## While scripted, the ship ignores input and its own clamp so a cutscene or
## an entry sequence can drive it directly.
func begin_scripted_move(wake_direction := Vector2.UP) -> void:
	_scripted = true
	velocity = Vector2.ZERO
	_external_force = Vector2.ZERO
	_move_intent = wake_direction

func end_scripted_move() -> void:
	_scripted = false
	_move_intent = Vector2.ZERO
	
func allow_forward_exit() -> void:
	_can_exit_forward = true


func _check_for_forward_exit() -> void:
	if not _can_exit_forward or _has_exited_play_area:
		return

	var visible_rect: Rect2 = Playarea.get_visible_world_rect()
	if global_position.y >= visible_rect.position.y - half_width:
		return

	_has_exited_play_area = true
	exited_play_area.emit()
		
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
	return (
		weapon != null
		and not _has_weapon(weapon)
		and _weapon_states.size() < max_weapons
	)


func add_weapon(weapon: WeaponData) -> bool:
	if not can_add_weapon(weapon):
		return false

	_weapon_states.append(WeaponState.new(weapon))
	return true


func get_weapon_count() -> int:
	return _weapon_states.size()


func can_add_augment(augment: AugmentData) -> bool:
	if (
		augment == null
		or augment.augmentEffect == null
		or _has_augment(augment)
	):
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
		_add_player_augment(augment, true)
		return true
		
	for state in _weapon_states:
		if state.data == augment.targetWeapon:
			state.augments.append(augment)
			augment_added.emit(augment)
			return true
	return false


func _add_player_augment(augment: AugmentData, notify: bool) -> void:
	_player_augments.append(augment)
	augment.augmentEffect.apply_to_player(self)
	if notify:
		augment_added.emit(augment)


func owns_pickup(pickup: PickupData) -> bool:
	if pickup == null:
		return false

	match pickup.pickup_type:
		PickupData.PickupType.WEAPON:
			return _has_weapon(pickup.weapon)
		PickupData.PickupType.AUGMENT:
			return _has_augment(pickup.augment)

	return false


func get_purchase_result(pickup: PickupData) -> PurchaseResult:
	if pickup == null or not pickup.is_sellable():
		return PurchaseResult.INVALID_ITEM
	if owns_pickup(pickup):
		return PurchaseResult.ALREADY_OWNED
	if not pickup.can_pickup(self):
		return PurchaseResult.CANNOT_ACCEPT
	if coin_count < pickup.get_shop_price():
		return PurchaseResult.NOT_ENOUGH_COINS
	return PurchaseResult.SUCCESS


func try_purchase(pickup: PickupData) -> PurchaseResult:
	if _purchase_in_progress:
		return PurchaseResult.CANNOT_ACCEPT

	var result := get_purchase_result(pickup)
	if result != PurchaseResult.SUCCESS:
		return result

	var price := pickup.get_shop_price()
	# This handles both the purchase and the purchase guard within the same function
	_purchase_in_progress = true
	if pickup.apply_to(self):
		coin_count -= price
		coin_changed.emit(coin_count)
		pickup_collected.emit(pickup)
		result = PurchaseResult.SUCCESS
	else:
		result = PurchaseResult.CANNOT_ACCEPT
	_purchase_in_progress = false
	return result


func _has_weapon(weapon: WeaponData) -> bool:
	if weapon == null:
		return false

	for state in _weapon_states:
		if state != null and state.data == weapon:
			return true

	return false


func _has_augment(augment: AugmentData) -> bool:
	if augment == null:
		return false

	if _player_augments.has(augment):
		return true

	for state in _weapon_states:
		if state != null and state.augments.has(augment):
			return true

	return false


func export_checkpoint() -> RunCheckpoint:
	var checkpoint := RunCheckpoint.new()
	checkpoint.coin_count = coin_count
	for state in _weapon_states:
		checkpoint.weapon_states.append(state.clone_for_checkpoint())
	checkpoint.player_augments.assign(_player_augments)
	checkpoint.potion_slots.assign(_potion_slots)
	checkpoint.selected_potion_slot = _selected_potion_slot
	return checkpoint


func import_checkpoint(checkpoint: RunCheckpoint) -> bool:
	if checkpoint == null:
		return false

	coin_count = checkpoint.coin_count
	for state in _weapon_states:
		state.stop_continuous_fire()
	_weapon_states.clear()
	for state in checkpoint.weapon_states:
		_weapon_states.append(state.clone_for_checkpoint())

	_player_augments.clear()
	for augment in checkpoint.player_augments:
		_add_player_augment(augment, false)

	_potion_slots.assign(checkpoint.potion_slots)
	_selected_potion_slot = 0 if _potion_slots.is_empty() else clampi(
		checkpoint.selected_potion_slot,
		0,
		_potion_slots.size() - 1
	)
	_emit_run_state_changed()
	return true


func _emit_run_state_changed() -> void:
	coin_changed.emit(coin_count)
	potion_inventory_changed.emit()
	potion_selection_changed.emit(_selected_potion_slot)

func set_can_switch_potion(value: bool) -> void:
	_can_switch_potion = value


func set_can_drink_potion(value: bool) -> void:
	_can_drink_potion = value
func can_add_potion(potion: PotionData) -> bool:
	return potion != null and has_potion_space()


func has_potion_space() -> bool:
	return _potion_slots.has(null)


func add_potion(potion: PotionData) -> bool:
	if not can_add_potion(potion):
		return false

	for index in range(_potion_slots.size()):
		if _potion_slots[index] == null:
			_potion_slots[index] = potion
			potion_inventory_changed.emit()
			return true

	return false


func select_potion_slot(index: int) -> void:
	if not _can_switch_potion: # Delete this
		return
	if _potion_slots.is_empty():
		return
	var wrapped_index := posmod(index, _potion_slots.size())
	if wrapped_index == _selected_potion_slot:
		return
	_selected_potion_slot = wrapped_index
	potion_selection_changed.emit(_selected_potion_slot)


func drink_selected_potion() -> bool:
	if not _can_drink_potion:
		return false
	var potion := get_potion_in_slot(_selected_potion_slot)
	if potion == null or not potion.use_on(self):
		return false

	_potion_slots[_selected_potion_slot] = null
	potion_inventory_changed.emit()
	potion_drunk.emit(potion)
	_emission.play(potion.cue)
	return true


func get_potion_slot_count() -> int:
	return _potion_slots.size()


func get_potion_in_slot(index: int) -> PotionData:
	if index < 0 or index >= _potion_slots.size():
		return null
	return _potion_slots[index]


func get_selected_potion_slot() -> int:
	return _selected_potion_slot

## Combat
func set_can_fire(allowed: bool) -> void:
	_can_fire = allowed
	
func _update_weapons(delta: float) -> void:
	var shoot_pressed := _can_fire and Input.is_action_pressed("shoot")
	var fire_rate := _status_effects.get_modified_value(
		StatusEffectData.STAT_FIRE_RATE,
		1.0
	)
	var cooldown_delta := delta * maxf(fire_rate, 0.0)
	
	for state in _weapon_states:
		if state.data.weaponBehaviour.update_continuous_fire(
			self, state, delta, shoot_pressed, fire_rate
		):
			state.cooldown = 0.0
			continue
		state.cooldown -= cooldown_delta
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
	if _health.current_health >= _health.max_health:
		health_full.emit()
		
func get_health_component() -> HealthComponent:
	return _health


func apply_status_effect(effect: StatusEffectData) -> bool:
	return _status_effects.apply_effect(effect)


func get_status_effect_component() -> StatusEffectComponent:
	return _status_effects

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
		_fit_wake_to_hull()
func _apply_tier() -> void:
	#Guard against null ship tier value
	if ship_tiers.is_empty():
		print("ship_tiers_empty")
		return
	#1. Apply Tier
	var tier := ship_tiers[clampi(ship_tier - 1, 0, ship_tiers.size() - 1)]
	#2. Apply Tier Texture
	#$Sprite2D.texture = tier.boat_texture   # art decides hull size, no scaling
	#3. Call function to fit animated wake to hull texture
	_fit_wake_to_hull()
	
	
	
	#SET SCALING
	#_sprite.scale = Vector2.ONE * tier.display_scale
	
	#IROH COMMENTED THIS OUT -- 30/8/2026 : Uncomment and fix this if necessary note...
	#SET HIT BOX CAPSULE RADIUS FOR TIER	
	#var hit := CapsuleShape2D.new()
	#hit.radius = tier.hitbox_radius
	#_hitbox_shape.shape = hit
	
	#SET PICKUP CRICLE RADIUS FOR TIER	
	#var pick := CircleShape2D.new()
	#pick.radius = tier.pickup_radius
	#_pickup_range_shape.shape = pick
#ship vfx 
func _fit_wake_to_hull() -> void:
	if ship_tiers.is_empty():
		return
	var tier_index := clampi(ship_tier - 1, 0, ship_tiers.size() - 1)
	var hull_w: float = ship_tiers[tier_index].pixel_hull_width
	var frame: Texture2D = $Wake.sprite_frames.get_frame_texture($Wake.animation, 0)
	var wake_w: float = frame.get_width()
	var fit_x := (hull_w / wake_w) * wake_overhang
	$Wake.scale = Vector2(fit_x, wake_length)
	print(wake_w)
	print(frame)
	print($Wake.scale)
	print("hull_w = ", $Sprite2D.texture.get_width())
func _update_wake() -> void:
	# Idle: no wake at all.
	if _move_intent.length() < WAKE_DEADZONE:
		if _wake.visible:
			_wake.stop()
			_wake.hide()
		return
	var anim := "wake_forward" #set animation to wake forward
	if _move_intent.x < -0.4: # Spelling mistake
		anim = "wake_strafe_left"
	elif _move_intent.x > 0.4: #if our x input above 0.1 that means we are moving right
		anim = "wake_strafe_right"
	if not _wake.visible:
		_wake.show()
	if _wake.animation != anim or not _wake.is_playing():
		_wake.play(anim)
	## else it stays "wake_forward" for up, down, and idle
	#if $Wake.animation != anim:
		#$Wake.play(anim)
func _update_masts() -> void:
	if ship_tiers.is_empty():
		return
	var tier := ship_tiers[clampi(ship_tier - 1, 0, ship_tiers.size() - 1)]
	_masts.visible = tier.has_masts
	if not tier.has_masts:
		return
	var is_moving: bool = _move_intent != Vector2.ZERO #if our moveintent is not 0 that means we are moving
	var lean := _move_intent.x * 45.0 #rotate masts left/right by 45 degrees
	for child in _masts.get_children():
		var mast := child as Mast
		mast.set_moving(is_moving)
		mast.rotation_degrees = lean
