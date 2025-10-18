extends CharacterBody3D

@onready var label: Label = $"../Label"

@export var move_speed: float = 10.0
@export var sprint_multiplier: float = 2.0
@export var mouse_sensitivity: float = 0.003
@export var reach_distance: float = 10.0  

@onready var camera: Camera3D = $Camera3D

var rotation_x: float = 0.0
var show_debug: bool = true

var world: Node3D
var hotbar: Hotbar
var selected_block_type: int = Block.BlockType.GRASS
var can_interact: bool = true
var interaction_cooldown: float = 0.0
var interaction_delay: float = 0.15  

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	world = get_node_or_null("/root/Node3D/World")
	if not world:
		world = get_node_or_null("../World")

	if not world:
		push_warning("World node not found! Block interaction will not work.")

	hotbar = get_node_or_null("../Gui/Control/Hotbar")
	if not hotbar:
		hotbar = get_node_or_null("/root/Node3D/Gui/Control/Hotbar")
	if not hotbar:
		hotbar = get_node_or_null("../Control/Hotbar")

	if hotbar:
		hotbar.slot_changed.connect(_on_hotbar_slot_changed)
		selected_block_type = hotbar.get_selected_block()
		print("Hotbar connected! Selected block: ", selected_block_type)
	else:
		push_warning("Hotbar not found! Using default block selection.")

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

	if interaction_cooldown > 0:
		interaction_cooldown -= delta
		if interaction_cooldown <= 0:
			can_interact = true

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_interact:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_break_block()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and can_interact:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_place_block()

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

func _on_hotbar_slot_changed(_slot_index: int, block_type: int):
	selected_block_type = block_type

func _break_block():
	if not world:
		return

	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z

	var result = world.raycast(camera_pos, camera_forward, reach_distance)

	if result.hit:

		world.set_block_at_world_pos(result.position, Block.BlockType.AIR)

		can_interact = false
		interaction_cooldown = interaction_delay

		print("Broke block at: ", result.position, " (type: ", result.block_type, ")")

func _place_block():
	if not world:
		return

	if selected_block_type == Block.BlockType.AIR:
		return

	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z

	var result = world.raycast(camera_pos, camera_forward, reach_distance)

	if result.hit:

		var place_pos = result.position + result.normal

		var player_aabb = AABB(global_position - Vector3(0.4, 0.9, 0.4), Vector3(0.8, 1.8, 0.8))
		var block_aabb = AABB(place_pos, Vector3.ONE)

		if not player_aabb.intersects(block_aabb):
			world.set_block_at_world_pos(place_pos, selected_block_type)

			can_interact = false
			interaction_cooldown = interaction_delay

			print("Placed ", _get_block_name(selected_block_type), " at: ", place_pos)

func _get_block_name(block_type: int) -> String:
	if hotbar:
		return hotbar.get_block_name(block_type)
	return "Block"
