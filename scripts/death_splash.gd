extends Node3D

var splash_colors: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE]

@onready var particles1: GPUParticles3D = $Particles1
@onready var particles2: GPUParticles3D = $Particles2
@onready var particles3: GPUParticles3D = $Particles3

func _ready() -> void:
	# Apply colors to each particle emitter
	_apply_color(particles1, splash_colors[0])
	_apply_color(particles2, splash_colors[1] if splash_colors.size() > 1 else splash_colors[0])
	_apply_color(particles3, splash_colors[2] if splash_colors.size() > 2 else splash_colors[0])

	# Start all emitters
	particles1.emitting = true
	particles2.emitting = true
	particles3.emitting = true

	# Auto-cleanup after particles finish
	await get_tree().create_timer(particles1.lifetime + 0.1).timeout
	queue_free()

func _apply_color(particles: GPUParticles3D, color: Color) -> void:
	var material = particles.process_material.duplicate() as ParticleProcessMaterial
	material.color = color
	particles.process_material = material

func set_colors(colors: Array[Color]) -> void:
	splash_colors = colors

# Legacy single-color support
func set_color(color: Color) -> void:
	splash_colors = [color, color, color]
