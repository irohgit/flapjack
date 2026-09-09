extends SceneTree

class FakePlayer extends Area2D:
	var damage_calls := 0
	func _init() -> void:
		add_to_group("player")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 10.0
		shape.shape = circle
		add_child(shape)
	func take_damage(_amount: int) -> void:
		damage_calls += 1

var _tick := 0
var _done := false
var _frog
var _sprite
var _player

func _process(_delta: float) -> bool:
	if _done:
		return true
	_tick += 1

	if _tick == 3:
		_setup()
	elif _tick == 4:
		print("default animation: ", _sprite.animation, " (expect Idle)")
		_frog._on_attack_zone_entered(_player)
	elif _tick == 5:
		print("_has_target() after entering: ", _frog._has_target(), " (expect true)")
	elif _tick == 10:
		_frog._on_tongue_extended()
		print("damage while overlapping (expect 1): ", _player.damage_calls)
		_frog._on_attack_zone_exited(_player)
		print("_has_target() after exiting: ", _frog._has_target(), " (expect false)")
		print("animation after exit: ", _sprite.animation, " (expect Idle)")
		_frog._on_tongue_extended()
		print("damage after exit, tongue callback still fires (expect still 1): ", _player.damage_calls)
		_done = true
		quit()
	return false

func _setup() -> void:
	var frog_scene := load("res://Actors/Enemies/frog_enemy.tscn") as PackedScene
	_frog = frog_scene.instantiate()
	root.add_child(_frog)
	_frog.global_position = Vector2(500, 500)
	_sprite = _frog.get_node("AnimatedSprite2D")

	_player = FakePlayer.new()
	root.add_child(_player)
	_player.global_position = _frog.global_position
