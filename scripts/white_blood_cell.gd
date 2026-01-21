extends CharacterBody3D

@export var move_speed: float = 1.5
@export var wander_range: float = 4.0

var wander_target: Vector3
var home_position: Vector3


func _ready() -> void:
	home_position = global_position
	add_to_group("enemies")
	pick_new_wander_target()


func _physics_process(delta: float) -> void:
	# Move toward wander target
	var direction = (wander_target - global_position).normalized()
	direction.y = 0

	velocity = direction * move_speed
	move_and_slide()

	# Face movement direction
	if velocity.length() > 0.1:
		rotation.y = atan2(velocity.x, velocity.z)

	# Pick new target when close
	if global_position.distance_to(wander_target) < 0.5:
		pick_new_wander_target()


func pick_new_wander_target() -> void:
	var random_offset = Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	wander_target = home_position + random_offset


func take_damage() -> void:
	queue_free()
