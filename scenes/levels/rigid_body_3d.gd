extends CharacterBody3D
@export var conductive := true

func _physics_process(delta):
	velocity = velocity.move_toward(Vector3.ZERO, 20 * delta)
	move_and_slide()
	
func _ready() -> void:
	if conductive:
		add_to_group("conductive")
