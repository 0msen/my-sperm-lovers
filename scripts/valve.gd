extends Node3D

## Hold-to-interact valve with regression
## Player must hold interact for [fill_time] seconds to complete
## Progress regresses over [regress_time] seconds when not interacting

signal valve_completed
signal valve_progress_changed(progress: float)
signal valve_started  # Emitted when player starts interacting
signal valve_stopped  # Emitted when player stops interacting

# --- Configuration ---
@export var fill_time: float = 10.0  # Seconds to complete
@export var regress_time: float = 120.0  # Seconds to fully regress
@export var interaction_range: float = 2.0  # How close player must be

# --- State ---
var progress: float = 0.0  # 0.0 to 1.0
var is_completed: bool = false
var is_being_used: bool = false
var player_in_range: bool = false
var player_ref: Node3D = null

# --- Nodes ---
@onready var interaction_area: Area3D = $InteractionArea
@onready var progress_bar: Node3D = get_node_or_null("ProgressBar3D")
# Wheel handle parts (for color change)
@onready var wheel: MeshInstance3D = get_node_or_null("WheelHandle/Wheel")
@onready var hub: MeshInstance3D = get_node_or_null("WheelHandle/Hub")
@onready var spoke1: MeshInstance3D = get_node_or_null("WheelHandle/Spoke1")
@onready var spoke2: MeshInstance3D = get_node_or_null("WheelHandle/Spoke2")

func _ready() -> void:
	add_to_group("valves")

	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	# Pass fill time to progress bar
	if progress_bar and progress_bar.has_method("set_fill_time"):
		progress_bar.set_fill_time(fill_time)

	_update_visuals()

func _process(delta: float) -> void:
	if is_completed:
		return

	if is_being_used and player_in_range:
		# Fill progress
		var fill_rate = 1.0 / fill_time
		progress += fill_rate * delta

		if progress >= 1.0:
			progress = 1.0
			_complete_valve()
	else:
		# Regress progress
		if progress > 0.0:
			var regress_rate = 1.0 / regress_time
			progress -= regress_rate * delta
			progress = max(0.0, progress)

	valve_progress_changed.emit(progress)
	_update_visuals()

func _input(event: InputEvent) -> void:
	if is_completed:
		return

	if not player_in_range:
		return

	# Check for shoot action (left click)
	if event.is_action_pressed("shoot"):
		_start_interaction()
	elif event.is_action_released("shoot"):
		_stop_interaction()

func _start_interaction() -> void:
	if is_being_used or is_completed:
		return

	is_being_used = true
	valve_started.emit()
	print("[Valve] Started interaction - progress: ", progress)

func _stop_interaction() -> void:
	if not is_being_used:
		return

	is_being_used = false
	valve_stopped.emit()
	print("[Valve] Stopped interaction - progress: ", progress)

func _complete_valve() -> void:
	is_completed = true
	is_being_used = false
	valve_completed.emit()
	print("[Valve] COMPLETED!")
	_update_visuals()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		print("[Valve] Player in range")

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		_stop_interaction()  # Force stop if player leaves range
		print("[Valve] Player left range")

func _update_visuals() -> void:
	# Determine color based on state
	var color: Color
	if is_completed:
		color = Color.GREEN
	elif is_being_used:
		color = Color.YELLOW
	else:
		color = Color(0.8, 0.2, 0.2, 1)  # Red

	# Update wheel handle parts color
	_set_mesh_color(wheel, color)
	_set_mesh_color(hub, color)
	_set_mesh_color(spoke1, color)
	_set_mesh_color(spoke2, color)

	# Update progress bar if exists
	if progress_bar and progress_bar.has_method("set_progress"):
		progress_bar.set_progress(progress)

func _set_mesh_color(mesh_node: MeshInstance3D, color: Color) -> void:
	if not mesh_node:
		return
	# Get or create material override
	var mat = mesh_node.get_surface_override_material(0)
	if not mat:
		mat = mesh_node.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		mesh_node.set_surface_override_material(0, mat)
	if mat:
		mat.albedo_color = color

# Called by external scripts to check if valve is active (for sperm attraction)
func is_active() -> bool:
	return is_being_used and not is_completed

func get_progress() -> float:
	return progress
