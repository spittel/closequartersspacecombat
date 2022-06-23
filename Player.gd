extends KinematicBody
##################################
# new control code
##################################
export var MAX_SPEED = 70
export var ACCELERATION = 0.8
export var PITCH_SPEED = 1.5
export var ROLL_SPEED = 1.9
export var yaw_speed = 1.25  # Set lower for linked roll/yaw
export var INPUT_RESPONSE = 8.0

var velocity = Vector3.ZERO

var forward_speed = 0
var horiz_speed = 0
var vert_speed = 0

var pitch_input = 0
var roll_input = 0
var yaw_input = 0

var is_free_look = false

const SAGGITAL_MULTIPLIER = 50
const FX_THRUST = .00005
const FX_RETRO_THRUST = .0005
const FX_GET_TO_CENTER = .001
const FX_PARTICLES = 200

var MOUSE_SENSITIVITY = 0.05
var camera
var rotation_helper

var thrusters = preload("res://assets/sounds/main_thrusters.mp3")
var sagittal = preload("res://assets/sounds/sagittal_thrusters.mp3")

var cam_origin = Vector3()

var free_look_thrust_count = 0

# contains thrusts over time, use the oldest one
var drift_thrusts = []
var drift_lag_count = 0;
const DRIFT_LAG = 75


func _ready():
	rotation_helper = $Rotation_Helper
	
	var camera_to_center_offset = $Camera_Spatial.translation - $Rotation_Helper.translation
	
	# prime drift
	for n in DRIFT_LAG:
		drift_thrusts.append(Vector3())
	
	cam_origin  = $Rotation_Helper.translation + camera_to_center_offset

func get_input(delta):
	# capturing/freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode((Input.MOUSE_MODE_VISIBLE))

	handle_thrust(delta)
			
	pitch_input = lerp(pitch_input,
			Input.get_action_strength("pitch_up") - Input.get_action_strength("pitch_down"),
			INPUT_RESPONSE * delta)
			
	roll_input = lerp(roll_input,
			Input.get_action_strength("roll_left") - Input.get_action_strength("roll_right"),
			INPUT_RESPONSE * delta)
			
	yaw_input = lerp(yaw_input,
			Input.get_action_strength("yaw_left") - Input.get_action_strength("yaw_right"),
			INPUT_RESPONSE * delta)

	handle_saggital_thrust(delta)


func handle_thrust(delta):
	handle_free_look(delta)
	
	if !Input.is_action_pressed("throttle_up") &&  !Input.is_action_pressed("throttle_down"):
		get_to_center()
		
		if(free_look_thrust_count <= 0):
			$MainThrusterSound.stop()
			
		return
		
	if Input.is_action_pressed("throttle_up"):
		forward_speed = lerp(forward_speed,
			Input.get_action_strength("throttle_up") * 100,
			ACCELERATION * delta)
		
		# visual fx
		if(forward_speed < MAX_SPEED):
			$Camera_Spatial.translate(Vector3(0, 0, forward_speed * FX_THRUST))
			
		thrust_sound()
		
	if Input.is_action_pressed("throttle_down"):
		forward_speed = lerp(forward_speed,
			-Input.get_action_strength("throttle_down")*50,
			ACCELERATION * delta)
		#simulate reverse
		$Camera_Spatial.translate(Vector3(0,0,-FX_RETRO_THRUST))
			
	forward_speed = cap_max_speed(forward_speed)
	
	$Camera_Spatial/Camera/particles.get_process_material().gravity = (Vector3(0, 0, forward_speed * FX_PARTICLES))

func cap_max_speed(forward_speed):
	if(forward_speed > MAX_SPEED):
		decel_to_center(FX_GET_TO_CENTER)
		forward_speed = MAX_SPEED
	
	return forward_speed

func handle_free_look(delta):
	is_free_look = Input.is_action_pressed("free_look")

	free_look_thrust_count -= delta
	
	if Input.is_action_just_released("free_look"):
		thrust_sound()
		free_look_thrust_count = 0.5

func thrust_sound():
	if !$MainThrusterSound.is_playing():
		$MainThrusterSound.stream = thrusters
		$MainThrusterSound.play()

func get_to_center():
	if($Camera_Spatial.translation.z > cam_origin.z):
		decel_to_center(FX_GET_TO_CENTER)
	elif($Camera_Spatial.translation.z < cam_origin.z):
		accel_to_center(FX_GET_TO_CENTER)

func decel_to_center(decel):
	if($Camera_Spatial.translation != cam_origin):
		if($Camera_Spatial.translation.z < cam_origin.z):
			# handle overshooting deceleration
			$Camera_Spatial.translation = cam_origin
		else:
			$Camera_Spatial.translation = $Camera_Spatial.translation + Vector3(0,0,-decel)

func accel_to_center(accel):
	if($Camera_Spatial.translation != cam_origin):
		if($Camera_Spatial.translation.z > cam_origin.z):
			# handle overshooting
			$Camera_Spatial.translation = cam_origin
		else:
			$Camera_Spatial.translation = $Camera_Spatial.translation + Vector3(0,0, accel)

func handle_saggital_thrust(delta):
	var horiz_input = Input.get_action_strength("horiz_right") * SAGGITAL_MULTIPLIER  - Input.get_action_strength("horiz_left") * SAGGITAL_MULTIPLIER
	horiz_speed = lerp(horiz_speed, horiz_input, INPUT_RESPONSE * delta)

	var vert_input = Input.get_action_strength("vert_up") * SAGGITAL_MULTIPLIER - Input.get_action_strength("vert_down") * SAGGITAL_MULTIPLIER
	vert_speed = lerp(vert_speed, vert_input, INPUT_RESPONSE * delta)

	if(horiz_input != 0 || vert_input !=0):
		if !$SaggitalThrusterSound.is_playing():
			$SaggitalThrusterSound.stream = sagittal
			$SaggitalThrusterSound.play()
	else:
		if $SaggitalThrusterSound.is_playing():
			$SaggitalThrusterSound.stop()


func _physics_process(delta):
	get_input(delta)
		
	transform.basis = transform.basis.rotated(transform.basis.z, roll_input * ROLL_SPEED * delta)
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * PITCH_SPEED * delta)
	transform.basis = transform.basis.rotated(transform.basis.y, yaw_input * yaw_speed * delta)
	
	transform.basis = transform.basis.orthonormalized()

	# is_free_look is when you just cut engines and can free look
	if !is_free_look:
		velocity = transform.basis.z * -forward_speed + transform.basis.y * vert_speed + transform.basis.x * horiz_speed
		#store current velocity for later!
		drift_thrusts.append(velocity)
		
		# use the last one, so input is laggy
		# make it more drifty (thrust lags direction pointed)
		velocity = drift_thrusts.pop_front()
		
	
	$HUD/Panel/Gun_label.text= "Velocity:" + str(int(forward_speed))
	
	move_and_collide(velocity * delta)
