extends Node

func break_block_with_raycast(world: Node3D, player_pos: Vector3, camera_dir: Vector3):
	var raycast_result = world.raycast(player_pos, camera_dir, 10.0)

	if raycast_result.hit:
		print("Hit block at: ", raycast_result.position)
		print("Block type: ", raycast_result.block_type)
		print("Face normal: ", raycast_result.normal)
		print("Distance: ", raycast_result.distance)

		world.set_block_at_world_pos(raycast_result.position, Block.BlockType.AIR)

		var place_pos = raycast_result.position + raycast_result.normal

func check_player_collision(world: Node3D, player_pos: Vector3, player_size: Vector3) -> bool:

	var player_aabb = AABB(player_pos - player_size / 2.0, player_size)

	var has_collision = world.check_collision(player_aabb)

	if has_collision:
		print("Player is colliding with terrain!")
		return true

	return false

func get_explosion_blocks(world: Node3D, center: Vector3, radius: float) -> Array[Vector3i]:
	var explosion_aabb = AABB(
		center - Vector3(radius, radius, radius),
		Vector3(radius * 2, radius * 2, radius * 2)
	)

	var blocks = world.query_region(explosion_aabb)
	print("Explosion would affect ", blocks.size(), " blocks")

	var sphere_blocks: Array[Vector3i] = []
	for block_pos in blocks:
		var block_center = Vector3(block_pos) + Vector3(0.5, 0.5, 0.5)
		if center.distance_to(block_center) <= radius:
			sphere_blocks.append(block_pos)

	return sphere_blocks

func has_line_of_sight(world: Node3D, from: Vector3, to: Vector3) -> bool:
	var direction = (to - from).normalized()
	var distance = from.distance_to(to)

	var raycast_result = world.raycast(from, direction, distance)

	return not raycast_result.hit or raycast_result.distance > distance

func find_ground_below(world: Node3D, pos: Vector3, max_depth: float = 100.0) -> Dictionary:
	var raycast_result = world.raycast(pos, Vector3.DOWN, max_depth)

	if raycast_result.hit:
		return {
			"found": true,
			"position": raycast_result.position + Vector3(0, 1, 0),  
			"distance": raycast_result.distance,
			"block_type": raycast_result.block_type
		}

	return {"found": false}

func is_position_safe_for_spawn(world: Node3D, pos: Vector3, entity_height: float = 2.0) -> bool:

	if world.is_solid_at(pos):
		return false

	var head_pos = pos + Vector3(0, entity_height, 0)
	if world.is_solid_at(head_pos):
		return false

	var ground_pos = pos - Vector3(0, 0.1, 0)
	if not world.is_solid_at(ground_pos):
		return false

	return true

func find_nearby_blocks(world: Node3D, center: Vector3, search_radius: float, block_type: int) -> Array[Vector3i]:
	var search_aabb = AABB(
		center - Vector3(search_radius, search_radius, search_radius),
		Vector3(search_radius * 2, search_radius * 2, search_radius * 2)
	)

	var all_blocks = world.query_region(search_aabb)
	var matching_blocks: Array[Vector3i] = []

	for block_pos in all_blocks:
		var actual_type = world.get_block_at_world_pos(Vector3(block_pos))
		if actual_type == block_type:
			matching_blocks.append(block_pos)

	return matching_blocks
