extends Node3D

# signals
signal cam_zoomed(new_distance, old_distance)
signal cam_panned(new_pan, old_pan)
signal cam_tilted(new_tilt, old_tilt)
signal screen_doubletapped(point)

# Zoom vars
@export_group("Zoom")
@export var can_zoom = true
@export var zoom_speed: float = 5.0
@export var min_zoom_m: float = 1.0
@export var max_zoom_m: float = 15.0
@export var min_pinch_detect_dist_pts: float = 20.0

# Pan vars
@export_group("Pan")
@export var can_pan = true
@export var pan_speed: float = 1.0

# Tilt vars
@export_group("Tilt")
@export var can_tilt = true
@export var tilt_speed: float = 0.75
@export var max_down_tilt: float = -90.0 #-90: look down to character from above it
@export var max_up_tilt: float = 70.0 #90: look up to character from below it
var _min_tilt: float #neg rad from max_down_tilt
var _max_tilt: float #neg rad from max_up_tilt


# Tap vars
@export_group("Taps")
@export var can_double_tap = false

# signals and actions
@export var use_signals: bool = true
@export var use_actions: bool = true
@export var input_action_doubletapped: String = ""

# Tree-Nodes
@onready var _cam_pan: Node3D = $CameraPan
@onready var _cam_tilt: Node3D = $CameraPan/CameraTilt
@onready var _cam_spring: SpringArm3D = $CameraPan/CameraTilt/SpringArm3D

# State vars
var _touch_points: Dictionary = {} # Dict to store all active touches
var _pinch_start_distance: float # to store initial 2 finger tap distance in pts
var _zoom_start_distance: float # to store initial cam zoom distance in m
var _zoom_distance: float
var _pan_drag_start_position: Vector2 = Vector2.ZERO # to store initial tap for pan drag distance calc
var _tilt_drag_start_position: Vector2 = Vector2.ZERO # to store initial tap for tilt drag distance calc
var _cam_start_pan: float # to mstore initial cam rot y before panning
var _cam_start_tilt: float # to store initial cam rot x before tilting
var _drag_started: bool = false

#
# Initialize
#
func _ready() -> void:
	_min_tilt = deg_to_rad(max_down_tilt)
	_max_tilt = deg_to_rad(max_up_tilt)
	_cam_spring.add_excluded_object(self)
	_zoom_distance = _cam_spring.spring_length

#
# Lerp zoom
#
func _physics_process(delta: float) -> void:
	var vec = Vector2(_cam_spring.spring_length, 0.0)
	vec = vec.lerp(Vector2(_zoom_distance, 0.0), delta * zoom_speed)
	_cam_spring.spring_length = vec.x
	if use_signals:
		cam_zoomed.emit(_zoom_distance, _zoom_start_distance)


#
# Process screen input events to filter touch and drag
#
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
		if _touch_points.size() == 1:
			_drag_started = true
		handle_touch(event)
	elif event is InputEventScreenDrag:
		# we only allow drags after we received a touch
		# this is required because we could receive drag events that have been started by a touch on another control
		if event.index in _touch_points:
			_touch_points[event.index] = event.position
			handle_drag(event)

#
# Handle touches and touch releases
#
func handle_touch(event: InputEventScreenTouch) -> void:
	
	# Detect double tap
	if event.double_tap:
		if use_signals:
			screen_doubletapped.emit(event.position)
		if use_actions:
			Input.action_press(input_action_doubletapped, 1.0)
			await get_tree().create_timer(0.1).timeout
			Input.action_release(input_action_doubletapped)
	
	if _touch_points.size() == 0:
		# Last touch has been released
		# Disable pinch gesture because currently no tap active
		_pinch_start_distance = 0.0
	
	elif _touch_points.size() == 1:
		# Disable pinch gesture because currently only one tap active
		_pinch_start_distance = 0.0
		
		if event.pressed:
			_drag_started = true
			
	elif _touch_points.size() == 2:
		# Store gesture
		_pinch_start_distance = get_pinch_distance()
		
		# store start zoom
		_zoom_start_distance = _cam_spring.spring_length
		
#
# Handle touch dragging with one or two fingers
#
func handle_drag(event: InputEventScreenDrag) -> void:
	# pan and tilt with one finger
	if _touch_points.size() == 1:
		# init drag
		if _drag_started:
			_drag_started = false
			# set drag start position: the only finger that touches
			_pan_drag_start_position = event.position
			_tilt_drag_start_position = event.position
			# remember cams pan and tilt on touch to have a base fot drag later on
			_cam_start_pan = _cam_pan.rotation.y
			_cam_start_tilt = _cam_tilt.rotation.x
			
		if can_pan:
			var dist = event.position - _pan_drag_start_position
			var rot = dist * TAU / get_viewport().get_visible_rect().size
			_cam_pan.rotation.y = clampf(_cam_start_pan - rot.x * pan_speed, -PI, PI)
			#print("CameraController panned to %f" % _cam_pan.rotation.y
			if use_signals:
				cam_panned.emit(_cam_pan.rotation.y, _cam_start_pan)
			
		if can_tilt:
			var dist = event.position - _tilt_drag_start_position
			var rot = dist * TAU / get_viewport().get_visible_rect().size
			_cam_tilt.rotation.x = clampf(_cam_start_tilt - rot.y * tilt_speed, _min_tilt, _max_tilt)
			#print("CameraController tilt to %f" % _cam_tilt.rotation.x
			if use_signals:
				cam_tilted.emit(_cam_tilt.rotation.x, _cam_start_tilt)
			
	# zoom with 2 fingers
	elif _touch_points.size() == 2 and can_zoom and _pinch_start_distance >= min_pinch_detect_dist_pts:
		var pinch_distance = get_pinch_distance()
		var zoom_factor = pinch_distance / _pinch_start_distance
		_zoom_distance = _zoom_start_distance / zoom_factor #* zoom_speed
		_zoom_distance = clampf(_zoom_distance, min_zoom_m, max_zoom_m)



#
# Return current two finger pinch gesture distance in pts
#
func get_pinch_distance() -> float:
	var touch_point_positions = _touch_points.values()
	if touch_point_positions.size() > 1:
		return touch_point_positions[0].distance_to(touch_point_positions[1])
	else:
		return 0.0

func get_pan() -> float:
	return(_cam_pan.global_rotation.y)
	
func reset_pan():
		#if _touch_points.size() == 1:
		_cam_pan.rotation.y = 0
		_cam_start_pan = 0
		var touch_point_positions = _touch_points.values()
		if touch_point_positions.size() > 0:
			_pan_drag_start_position = touch_point_positions[0]
	
