extends Node3D

@export var fill_color: Color = Color(0.94, 0.94, 0.88, 1)  # Cream
@export var background_color: Color = Color(0.25, 0.25, 0.25, 1)  # Dark grey
@export var border_color: Color = Color.BLACK
@export var border_width: int = 3
@export var always_visible: bool = true
@export var hide_delay: float = 3.0
@export var flash_duration: float = 0.1
@export var shake_intensity: float = 3.0

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var sprite: Sprite3D = $Sprite3D

var hide_timer: float = 0.0
var current_health: int = 0


func _ready() -> void:
	setup_colors()
	if not always_visible:
		hide()


func _process(delta: float) -> void:
	if not always_visible and visible:
		hide_timer -= delta
		if hide_timer <= 0:
			hide()


func setup_colors() -> void:
	# Fill style - solid color, no border
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 0
	fill_style.corner_radius_top_right = 0
	fill_style.corner_radius_bottom_left = 0
	fill_style.corner_radius_bottom_right = 0
	progress_bar.add_theme_stylebox_override("fill", fill_style)

	# Background style - with thick border
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = background_color
	bg_style.border_color = border_color
	bg_style.border_width_left = border_width
	bg_style.border_width_right = border_width
	bg_style.border_width_top = border_width
	bg_style.border_width_bottom = border_width
	bg_style.corner_radius_top_left = 0
	bg_style.corner_radius_top_right = 0
	bg_style.corner_radius_bottom_left = 0
	bg_style.corner_radius_bottom_right = 0
	progress_bar.add_theme_stylebox_override("background", bg_style)


func update_health(current: int, maximum: int) -> void:
	var took_damage = current < current_health
	current_health = current

	progress_bar.max_value = maximum
	progress_bar.value = current

	if took_damage:
		play_damage_effect()

	if not always_visible:
		show()
		hide_timer = hide_delay


func play_damage_effect() -> void:
	# Flash white
	var fill_style = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var original_color = fill_color
	fill_style.bg_color = Color.WHITE

	# Shake
	var original_pos = progress_bar.position
	var tween = create_tween()
	tween.tween_property(progress_bar, "position", original_pos + Vector2(shake_intensity, 0), 0.05)
	tween.tween_property(progress_bar, "position", original_pos - Vector2(shake_intensity, 0), 0.05)
	tween.tween_property(progress_bar, "position", original_pos, 0.05)

	# Restore color after flash
	await get_tree().create_timer(flash_duration).timeout
	fill_style.bg_color = original_color
