extends CharacterBody3D

@onready var label: Label = $"../Label"

@export var move_speed: float = 10.0
@export var sprint_multiplier: float = 2.0
@export var mouse_sensitivity: float = 0.003

@onready var camera: Camera3D = $Camera3D

var rotation_x: float = 0.0
var show_debug: bool = true

func _ready() -> void:

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

		rotate_y(-event.relative.x * mouse_sensitivity)

		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -PI/2, PI/2)
		camera.rotation.x = rotation_x

	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_f3"):
		show_debug = !show_debug
		label.visible = show_debug

func _physics_process(delta: float) -> void:

	var input_dir = Input.get_vector("pm_moveleft", "pm_moveright", "pm_moveforward", "pm_movebackward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if Input.is_physical_key_pressed(KEY_Q):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_E):
		direction.y += 1

	direction = direction.normalized()

	var speed = move_speed
	if Input.is_action_pressed("pm_sprint"):
		speed *= sprint_multiplier

	position += direction * speed * delta

	if show_debug:
		update_debug_info(delta)

func update_debug_info(_delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	var pos = position
	var rot = rotation_degrees
	var cam_rot = camera.rotation_degrees

	var forward = -transform.basis.z
	var facing = ""
	if abs(forward.x) > abs(forward.z):
		facing = "East" if forward.x > 0 else "West"
	else:
		facing = "South" if forward.z > 0 else "North"

	label.text = "Godot Engine %s
FPS: %d

XYZ: %.3f / %.3f / %.3f
Facing: %s (%.1f / %.1f)
Rotation: %.1f / %.1f / %.1f

Speed: %.1f
" % [
		Engine.get_version_info().string,
		fps,
		pos.x, pos.y, pos.z,
		facing, rot.y, cam_rot.x,
		rot.x, rot.y, rot.z,
		move_speed * (sprint_multiplier if Input.is_action_pressed("pm_sprint") else 1.0)
	]
