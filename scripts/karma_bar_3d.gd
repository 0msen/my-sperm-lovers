extends Node3D

@export var positive_color: Color = Color(0.5, 0.5, 0.5, 1)  # Grey for positive karma
@export var negative_color: Color = Color(0.5, 0.13, 0.13, 1)  # Maroon for negative karma
@export var empty_color: Color = Color(0.15, 0.15, 0.15, 1)  # Dark for empty segments
@export var border_color: Color = Color.BLACK
@export var segment_count: int = 5  # Number of segments in the bar

@onready var sprite: Sprite3D = $Sprite3D
@onready var subviewport: SubViewport = $SubViewport
@onready var level_label: Label = $SubViewport/HBoxContainer/LevelLabel
@onready var segments_container: HBoxContainer = $SubViewport/HBoxContainer/SegmentsContainer

var current_level: int = 0
var is_positive: bool = true
var segment_panels: Array[Panel] = []


func _ready() -> void:
	_create_segments()
	if GameManager:
		GameManager.karma_updated.connect(_on_karma_updated)
	_update_display(0, 0.0, true)


func _create_segments() -> void:
	# Clear existing segments
	for child in segments_container.get_children():
		child.queue_free()
	segment_panels.clear()

	# Create segment panels
	for i in range(segment_count):
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(18, 24)

		var style = StyleBoxFlat.new()
		style.bg_color = empty_color
		style.border_color = border_color
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0

		panel.add_theme_stylebox_override("panel", style)
		segments_container.add_child(panel)
		segment_panels.append(panel)


func _on_karma_updated(level: int, progress: float, karma_is_positive: bool) -> void:
	current_level = level
	is_positive = karma_is_positive
	_update_display(level, progress, karma_is_positive)


func _update_display(level: int, progress: float, karma_is_positive: bool) -> void:
	# Update level label
	if level_label:
		level_label.text = str(level)

	# Calculate how many segments to fill
	var filled_segments = int(progress * segment_count)
	var fill_color = positive_color if karma_is_positive else negative_color

	# Update segment colors
	for i in range(segment_panels.size()):
		var panel = segment_panels[i]
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if i < filled_segments:
				style.bg_color = fill_color
			else:
				style.bg_color = empty_color
