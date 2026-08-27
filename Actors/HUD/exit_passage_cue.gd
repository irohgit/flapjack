class_name ExitPassageCue
extends Control


const LINE_Y := 22.0
const PARTICLES_PER_SECOND := 18.0
const INITIAL_PARTICLE_COUNT := 12


class SquareParticle:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var size := 4.0
	var age := 0.0
	var lifetime := 3.0
	var sway_phase := 0.0
	var sway_speed := 1.0


var _particles: Array[SquareParticle] = []
var _spawn_progress := 0.0
var _elapsed := 0.0


func _ready() -> void:
	for _index in INITIAL_PARTICLE_COUNT:
		var particle := _new_particle()
		particle.age = randf_range(0.0, particle.lifetime * 0.7)
		particle.position += particle.velocity * particle.age
		_particles.append(particle)


func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_progress += delta * PARTICLES_PER_SECOND

	while _spawn_progress >= 1.0:
		_particles.append(_new_particle())
		_spawn_progress -= 1.0

	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		particle.age += delta
		if particle.age >= particle.lifetime:
			_particles.remove_at(index)
			continue

		particle.position += particle.velocity * delta
		particle.position.x += sin(
			_elapsed * particle.sway_speed + particle.sway_phase
		) * 8.0 * delta

	queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + sin(_elapsed * 2.5) * 0.15
	var line_start := Vector2(0.0, LINE_Y)
	var line_end := Vector2(size.x, LINE_Y)

	# Three strokes make the glow without needing another texture or shader.
	draw_line(line_start, line_end, Color(1.0, 1.0, 1.0, 0.08 * pulse), 28.0, true)
	draw_line(line_start, line_end, Color(1.0, 1.0, 1.0, 0.24 * pulse), 12.0, true)
	draw_line(line_start, line_end, Color(1.0, 1.0, 1.0, 0.95 * pulse), 2.0, true)

	for particle in _particles:
		var progress := clampf(particle.age / particle.lifetime, 0.0, 1.0)
		var alpha := sin(progress * PI)
		var particle_rect := Rect2(
			particle.position - Vector2.ONE * particle.size * 0.5,
			Vector2.ONE * particle.size
		)
		draw_rect(particle_rect.grow(3.0), Color(1.0, 1.0, 1.0, alpha * 0.12))
		draw_rect(particle_rect, Color(1.0, 1.0, 1.0, alpha * 0.9))


func _new_particle() -> SquareParticle:
	var particle := SquareParticle.new()
	particle.position = Vector2(
		randf_range(24.0, maxf(size.x - 24.0, 24.0)),
		LINE_Y + randf_range(2.0, 9.0)
	)
	particle.velocity = Vector2(randf_range(-5.0, 5.0), randf_range(30.0, 65.0))
	particle.size = randf_range(3.0, 7.0)
	particle.lifetime = randf_range(2.8, 4.8)
	particle.sway_phase = randf() * TAU
	particle.sway_speed = randf_range(0.8, 1.8)
	return particle
