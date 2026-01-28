extends Area3D

@export var damage := 1
@export var tick_rate := 0.5

var bodies_in_acid := []
var tick_timer := 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		bodies_in_acid.append(body)

func _on_body_exited(body):
	bodies_in_acid.erase(body)

func _physics_process(delta):
	if bodies_in_acid.is_empty():
		return

	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		for body in bodies_in_acid:
			if body.has_method("take_damage"):
				body.take_damage(damage, global_position, false)
