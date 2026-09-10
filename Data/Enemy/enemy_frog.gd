class_name EnemyFrog
extends Enemy

const ATTACK_INTERVAL := 1.2

const TONGUE_CONTACT_DELAY := 0.5

@onready var _attack_zone: Area2D = $AttackZone

var _target: Node2D = null
var _attack_cooldown := 0.0


func _ready() -> void:
	assert(data != null, "Enemy spawned with no EnemyData assigned")

	_animated_sprite.sprite_frames = data.sprite_frames

	_attack_zone.area_entered.connect(_on_attack_zone_entered)
	_attack_zone.area_exited.connect(_on_attack_zone_exited)

	# The base contact-damage mask only looks for enemy_bullet (layer 3).
	# Add the player layer so this body's own get_overlapping_areas() can
	# tell whether the player is actually within the tongue's reach.
	set_collision_mask_value(1, true)

	_animated_sprite.play(&"Idle")

# Frogs have no HealthComponent and can't be hit by player weapons.
func take_damage(_amount: int) -> void:
	pass

func apply_status_effect(_effect: StatusEffectData) -> bool:
	return false

func _on_attack_zone_entered(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	_target = area
	_attack_cooldown = 0.0

func _on_attack_zone_exited(area: Area2D) -> void:
	if area != _target:
		return
	_target = null
	# Attack loops on its own once started; without this it would keep
	# looping forever even after the player has left.
	_animated_sprite.play(&"Idle")

func _has_target() -> bool:
	return _target != null and is_instance_valid(_target)

func _physics_process(delta: float) -> void:
	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()
		return

	if _has_target():
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_attack()
			_attack_cooldown = ATTACK_INTERVAL

func _attack() -> void:
	_animated_sprite.play(&"Attack")
	get_tree().create_timer(TONGUE_CONTACT_DELAY).timeout.connect(_on_tongue_extended)

# AttackZone only decided when to start attacking. Whether the tongue
# actually lands is a separate, tighter check: is the player inside this
# body's own CollisionShape2D (sized to the tongue's full reach) right now.
func _on_tongue_extended() -> void:
	if not _has_target():
		return
	if not get_overlapping_areas().has(_target):
		return
	if _target.has_method("take_damage"):
		_target.take_damage(data.projectile_damage)
