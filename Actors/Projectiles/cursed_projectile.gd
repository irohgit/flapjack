class_name CursedProjectile
extends Projectile

@export_group("Curse Visuals")
@export var frames: SpriteFrames
@export var normal_animation: StringName = &"normal"
@export var ghost_animation: StringName = &"ghost"
@export var curse_flash_colour := Color(0.5, 1.0, 0.7)
@export_range(-180.0, 180.0, 90.0) var sprite_angle_offset := 90.0 #offset as anim2d assumes art faces right 

@export_group("Curse Effect")
## Gold taken per hit. If the purse cannot cover it, the shot damages instead.
@export var steal_amount := 1
@export var curse_sfx: AudioStream
@export var steal_sfx: AudioStream

var _moonlight: MoonlightDirector = null
var _moonlight_checked := false
var _cursed := false


func is_cursed() -> bool:
	return _cursed


## Always animated, unlike the base which only animates when overridden.
func _apply_visuals() -> void:
	if frames == null:
		super()
		return
	_sprite.visible = false
	_animated_sprite.visible = true
	_animated_sprite.sprite_frames = frames
	_animated_sprite.play(normal_animation)


func _physics_process(delta: float) -> void:
	_update_curse()
	super(delta)


func _update_curse() -> void:
	if _is_destroying:
		return
	if not _moonlight_checked:
		_moonlight_checked = true
		_moonlight = get_tree().get_first_node_in_group("moonlight") as MoonlightDirector
	if _moonlight == null:
		return

	var lit := _moonlight.is_lit(global_position)
	if lit == _cursed:
		return
	_set_cursed(lit)


func _set_cursed(value: bool) -> void:
	_cursed = value
	if frames != null:
		_animated_sprite.play(ghost_animation if value else normal_animation)
	if not value:
		return

	if curse_sfx != null:
		Audio.play_sfx(curse_sfx, -10.0)

	# The turn must be readable. A quiet tint change is not enough.
	var tween := create_tween()
	tween.tween_property(_animated_sprite, "modulate", curse_flash_colour, 0.06)
	tween.tween_property(_animated_sprite, "modulate", Color.WHITE, 0.18)


## Steals instead of damaging, but only from the player and only if the
## purse can pay. An empty purse turns the curse back into an ordinary shot.
func _consume_hit(area: Area2D) -> bool:
	if not _cursed:
		return false
	var player := area as Player
	if player == null:
		return false
	if not player.try_steal_coins(steal_amount):
		return false
	if steal_sfx != null:
		Audio.play_sfx(steal_sfx)
	return true


func _update_rotation(delta: float) -> void:
	super(delta)
	if data.spin_speed != 0.0:
		return
	_animated_sprite.rotation = direction.angle() + deg_to_rad(sprite_angle_offset)
