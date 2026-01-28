extends Area3D

signal power_changed(plate: Node, amount: int)

@onready var visual: Node3D = $Visual
@onready var mesh: MeshInstance3D = $Visual/Visual
var mat: StandardMaterial3D
var inactive_color := Color(1, 1, 1) # gray
var active_color := Color(0, 1, 0)   # green

var bodies_on_plate := {}
var is_active := false
var base_y := 0.0
var tween: Tween

func _ready():
	base_y = visual.position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Ensure material exists
	mat = StandardMaterial3D.new()
	mesh.material_override = mat

	mat.emission_enabled = true
	_set_color(inactive_color)
	if mesh.material_override:
		mat = mesh.material_override.duplicate()
		mesh.material_override = mat
	else:
		var surface_mat = mesh.mesh.surface_get_material(0)
		if surface_mat:
			mat = surface_mat.duplicate()
		else:
			mat = StandardMaterial3D.new() # 👈 CREATE ONE
		mesh.mesh.surface_set_material(0, mat)
	_set_color(inactive_color)

func _on_body_entered(body: Node3D):
	print("DETECTED:", body.name)
	if not body.is_in_group("conductive"):
		return

	bodies_on_plate[body.get_instance_id()] = body
	print("ENTER:", body.name)

	if not is_active:
		is_active = true
		_press_down()
		_set_color(active_color)
		emit_signal("power_changed", 1)
		print("⚡ Plate ON")

func _on_body_exited(body: Node3D):
	if not body.is_in_group("conductive"):
		return

	bodies_on_plate.erase(body.get_instance_id())
	print("EXIT:", body.name)

	if bodies_on_plate.is_empty():
		is_active = false
		_release()
		emit_signal("power_changed", -1)
		_set_color(inactive_color)
		print("❌ Plate OFF")
		
func _set_color(color: Color):
	if not mat:
		return

	mat.albedo_color = color

	mat.emission_enabled = true
	mat.emission = color
	
func _press_down():
	_animate_to(base_y - 0.15)

func _release():
	_animate_to(base_y)

func _animate_to(y: float):
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(visual, "position:y", y, 0.15)
