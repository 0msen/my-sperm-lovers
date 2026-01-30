extends StaticBody3D

const DeathSplash = preload("res://scenes/effects/death_splash.tscn")

@export var max_health: int = 5
@export var pulse_speed: float = 1.5
@export var pulse_scale_min: float = 0.9
@export var pulse_scale_max: float = 1.1

var health: int
var is_dead: bool = false
var base_scale: Vector3

signal destroyed

@onready var hp_bar: Node3D = $HPBar
@onready var mesh: Node3D = $Heart  # The visual mesh

func _ready() -> void:
	health = max_health
	base_scale = mesh.scale if mesh else Vector3(0.25, 0.25, 0.25)
	add_to_group("enemies")  # So bullets can hit it
	
	if hp_bar:
		hp_bar.update_health(health, max_health)
	
	# Start the ominous pulsing
	_start_pulse()

func _start_pulse() -> void:
	if is_dead or not mesh:
		return
	
	var tween = create_tween()
	tween.set_loops()  # Infinite loop
	tween.tween_property(mesh, "scale", base_scale * pulse_scale_max, pulse_speed / 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh, "scale", base_scale * pulse_scale_min, pulse_speed / 2.0).set_trans(Tween.TRANS_SINE)

func take_damage(amount: int) -> bool:
	if is_dead:
		return false
	
	health -= amount
	print("Fuse Box took ", amount, " damage! Health: ", health)
	
	if hp_bar:
		hp_bar.update_health(health, max_health)
	
	# Visual feedback - flash red or shake
	_damage_feedback()
	
	if health <= 0:
		die()
		return true
	return false

func _damage_feedback() -> void:
	if not mesh:
		return
	# Quick scale punch on hit
	var tween = create_tween()
	tween.tween_property(mesh, "scale", base_scale * 1.3, 0.05)
	tween.tween_property(mesh, "scale", base_scale, 0.1)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	print("Fuse Box destroyed!")
	
	# Spawn death effect
	var splash = DeathSplash.instantiate()
	var colors: Array[Color] = [
		Color(1.0, 0.2, 0.2),    # Bright red
		Color(0.8, 0.0, 0.0),    # Dark red
		Color(1.0, 0.5, 0.0),    # Orange (sparks)
	]
	splash.set_colors(colors)
	get_tree().current_scene.add_child(splash)
	splash.global_position = global_position
	
	# Karma penalty for violence
	if GameManager:
		GameManager.add_karma_xp(-25.0)  # Big karma hit for destroying the heart
	
	# Signal the level that we're destroyed
	destroyed.emit()
	
	# Hide or remove self
	visible = false
	set_collision_layer_value(1, false)  # Disable collision
