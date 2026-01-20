extends Area3D

@export var speed: float = 20.0
@export var lifetime: float = 2.0

var direction := Vector3.FORWARD

func _ready() -> void:
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Connect signal for hits
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		body.take_damage()
		queue_free()  # Only destroy when hitting an enemy
