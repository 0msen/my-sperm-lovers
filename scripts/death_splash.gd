extends Node3D

var splash_color: Color = Color.WHITE

@onready var particles: GPUParticles3D = $GPUParticles3D

func _ready() -> void:
	# Apply color now that we're in the tree
	var material = particles.process_material.duplicate() as ParticleProcessMaterial
	material.color = splash_color
	particles.process_material = material

	particles.emitting = true
	# Auto-cleanup after particles finish
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	queue_free()

func set_color(color: Color) -> void:
	# Store color to be applied in _ready()
	splash_color = color
