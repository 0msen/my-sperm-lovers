extends Node3D

var idle_position := Vector3(0.302, 0.678, 0.409)
var idle_rotation := Vector3(12.0, -35.4, 0.0)

@export var aim_position := Vector3(0.0, 0.5, 0.5)
@export var aim_rotation := Vector3(0.0, 0.0, 0.0)
@export var aim_speed := 15.0

@onready var player: CharacterBody3D = get_parent()

func _ready() -> void:
	position = idle_position
	rotation_degrees = idle_rotation

func _process(delta: float) -> void:
	var target_pos := aim_position if (player and player.is_aiming) else idle_position
	var target_rot := aim_rotation if (player and player.is_aiming) else idle_rotation
	
	position = position.lerp(target_pos, aim_speed * delta)
	rotation_degrees = rotation_degrees.lerp(target_rot, aim_speed * delta)
