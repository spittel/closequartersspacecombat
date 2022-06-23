extends KinematicBody
##################################
# new control code
##################################
export var max_speed = 70
export var acceleration = 0.8
export var pitch_speed = 1.5
export var roll_speed = 1.9
export var yaw_speed = 1.25  # Set lower for linked roll/yaw
export var input_response = 8.0

var velocity = Vector3.ZERO

var forward_speed = 0
var horiz_speed = 0
var vert_speed = 0

var pitch_input = 0
var roll_input = 0
var yaw_input = 0

var is_drift = false

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

func _ready():
	rotation_helper = $Rotation_Helper
	
	var camera_to_center_offset = $Camera_Spatial.translation - $Rotation_Helper.translation
	
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
			input_response * delta)
			
	roll_input = lerp(roll_input,
			Input.get_action_strength("roll_left") - Input.get_action_strength("roll_right"),
			input_response * delta)
			
	yaw_input = lerp(yaw_input,
			Input.get_action_strength("yaw_left") - Input.get_action_strength("yaw_right"),
			input_response * delta)

	handle_saggital_thrust(delta)
	
var drift_thrust_count = 0

func handle_thrust(delta):
	handle_drift(delta)
	
	if !Input.is_action_pressed("throttle_up") &&  !Input.is_action_pressed("throttle_down"):
		get_to_center()
		
		if(drift_thrust_count<=0):
			$MainThrusterSound.stop()
		return
		
	if Input.is_action_pressed("throttle_up"):
		forward_speed = lerp(forward_speed,
			Input.get_action_strength("throttle_up") * 100,
			acceleration * delta)
		
		# visual fx
		if(forward_speed < max_speed):
			$Camera_Spatial.translate(Vector3(0, 0, forward_speed * FX_THRUST))
			
		thrust_sound()
		
	if Input.is_action_pressed("throttle_down"):
		forward_speed = lerp(forward_speed,
			-Input.get_action_strength("throttle_down")*50,
			acceleration * delta)
		#simulate reverse
		$Camera_Spatial.translate(Vector3(0,0,-FX_RETRO_THRUST))
			
	if(forward_speed > max_speed):
		decel_to_center(FX_GET_TO_CENTER)
		forward_speed = max_speed

	$Camera_Spatial/Camera/particles.get_process_material().gravity = (Vector3(0, 0, forward_speed * FX_PARTICLES))

func handle_drift(delta):
	is_drift = Input.is_action_pressed("drift")

	drift_thrust_count-=delta
	
	if Input.is_action_just_released("drift"):
		thrust_sound()
		drift_thrust_count = 0.5

	
	
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
	horiz_speed = lerp(horiz_speed, horiz_input, input_response * delta)

	var vert_input = Input.get_action_strength("vert_up") * SAGGITAL_MULTIPLIER - Input.get_action_strength("vert_down") * SAGGITAL_MULTIPLIER
	vert_speed = lerp(vert_speed, vert_input, input_response * delta)

	if(horiz_input != 0 || vert_input !=0):
		if !$SaggitalThrusterSound.is_playing():
			$SaggitalThrusterSound.stream = sagittal
			$SaggitalThrusterSound.play()
	else:
		if $SaggitalThrusterSound.is_playing():
			$SaggitalThrusterSound.stop()


func _physics_process(delta):
	get_input(delta)
	
	var previous_velocity = velocity
	
	transform.basis = transform.basis.rotated(transform.basis.z, roll_input * roll_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.y, yaw_input * yaw_speed * delta)
	
	transform.basis = transform.basis.orthonormalized()

	if !is_drift:
		velocity = transform.basis.z * -forward_speed + transform.basis.y * vert_speed + transform.basis.x * horiz_speed
#		velocity -=previous_velocity
	
	$HUD/Panel/Gun_label.text= "Velocity:" + str(int(forward_speed))
	
	move_and_collide(velocity * delta)
