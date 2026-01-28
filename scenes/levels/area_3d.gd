extends Area3D

signal power_on
signal power_off
signal power_changed(amount: int)

@onready var visual: Node3D = $Visual

var active_count := 0
var base_y := 0.0
var tween: Tween


func _ready():
	assert(visual != null, "Visual node not found!")
	base_y = visual.position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D):
	print("ENTER:", body.name, body.get_class(), body.get_groups())
	if body.is_in_group("conductive"):
		active_count += 1
		print("⚡ Plate powered by:", body.name)

		if active_count == 1:
			_press_down()
			emit_signal("power_on")

		emit_signal("power_changed", active_count)


func _on_body_exited(body: Node3D):
	if body.is_in_group("conductive"):
		active_count -= 1
		active_count = max(active_count, 0)
		print("❌ Plate lost:", body.name)

		if active_count == 0:
			_release()
			emit_signal("power_off")

		emit_signal("power_changed", active_count)


func _press_down():
	_animate_to(base_y - 0.1)


func _release():
	_animate_to(base_y)


func _animate_to(y: float):
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(visual, "position:y", y, 0.15)
