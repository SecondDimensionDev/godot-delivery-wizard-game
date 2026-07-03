@icon("uid://bfg5woqf3ojra")
class_name DebugTopDownSteering
extends Node2D

@export var steering_component: TopDownSteeringController
@export var show_debug_rays: bool = false

var _debug_scores: Array[float] = []
var _debug_best_dir: Vector2 = Vector2.ZERO
var _debug_ray_directions: Array[Vector2] = []
var _debug_ray_count: int
var _debug_danger: Array[float] = []
var _debug_look_ahead_distance: float 


func _physics_process(_delta: float) -> void:
	if show_debug_rays:
		_debug_scores = steering_component._debug_scores
		_debug_best_dir = steering_component._debug_best_dir
		_debug_ray_directions = steering_component._ray_directions
		_debug_ray_count = steering_component.ray_count
		_debug_danger = steering_component._danger
		_debug_look_ahead_distance = steering_component.look_ahead_distance
		queue_redraw()


func _draw() -> void:
	if not show_debug_rays or _debug_ray_directions.is_empty():
		return
		
	for i in range(_debug_ray_count):
		var dir := _debug_ray_directions[i]
		var score := _debug_scores[i]
		var danger := _debug_danger[i]
		
		var ray_color := Color.DARK_GRAY
		var line_width := 2.0
		
		# If danger is 1.0, the ray hit a wall. Color it RED.
		if danger > 0.0:
			ray_color = Color.RED
		# Otherwise, color it based on its interest score (White/Greenish)
		elif score > 0.0:
			ray_color = Color(0.2, 1.0, 0.2, score) # Fades out lower scores
			
		# Highlight the actual chosen direction in bright cyan and make it thicker
		if dir == _debug_best_dir:
			ray_color = Color.CYAN
			line_width = 4.0
			
		var end_point := dir * _debug_look_ahead_distance
		draw_line(Vector2.ZERO, end_point, ray_color, line_width)
