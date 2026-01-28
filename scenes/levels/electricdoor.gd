extends Node3D

@export var required_power: int = 2

@onready var anim: AnimationPlayer = $DoorAnimation
@onready var door_body: StaticBody3D = $StaticBody3D
@onready var collider: CollisionShape3D = $StaticBody3D/CollisionShape3D

var current_power := 0
var is_open := false

func _ready():
	await get_tree().process_frame
	force_close()
	
func force_close():
	is_open = true 
	if anim.has_animation("close"):
		anim.play("close")
	is_open = false

func set_power(amount: int) -> void:
	current_power += amount
	current_power = max(0, current_power)

	print("🔌 Door power:", current_power, "/", required_power)

	if current_power >= required_power:
		open_door()
	else:
		close_door()

func open_door():
	if is_open:
		return
	is_open = true

	if anim.has_animation("open"):
		anim.play("open")


func close_door():
	if not is_open:
		return
	is_open = false

	if anim.has_animation("close"):
		anim.play("close")
