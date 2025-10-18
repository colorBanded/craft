extends RefCounted
class_name Octree

const MIN_NODE_SIZE = 8  
const MAX_DEPTH = 4  

class OctreeNode:
	var bounds: AABB  
	var is_leaf: bool = true
	var is_empty: bool = true
	var is_solid: bool = false  
	var children: Array = []  
	var block_type: int = -1  

	func _init(aabb: AABB):
		bounds = aabb

	func get_child_index(pos: Vector3) -> int:
		var center = bounds.position + bounds.size / 2.0
		var index = 0
		if pos.x >= center.x: index |= 1
		if pos.y >= center.y: index |= 2
		if pos.z >= center.z: index |= 4
		return index

	func subdivide():
		if not is_leaf:
			return  

		is_leaf = false
		children.resize(8)

		var half_size = bounds.size / 2.0
		for i in range(8):
			var offset = Vector3(
				half_size.x if (i & 1) else 0,
				half_size.y if (i & 2) else 0,
				half_size.z if (i & 4) else 0
			)
			var child_aabb = AABB(bounds.position + offset, half_size)
			children[i] = OctreeNode.new(child_aabb)

var root: OctreeNode
var world_size: Vector3i

func _init(size: Vector3i = Vector3i(256, 256, 256)):
	world_size = size

	root = OctreeNode.new(AABB(Vector3.ZERO, Vector3(size)))

func insert_chunk(chunk_pos: Vector3i, chunk_data, chunk_size: int = 16):
	var start_pos = Vector3(chunk_pos * chunk_size)

	for x in range(chunk_size):
		for z in range(chunk_size):
			for y in range(chunk_size):
				var block = chunk_data.get_block(x, y, z)
				if block != Block.BlockType.AIR:
					var world_pos = start_pos + Vector3(x, y, z)
					_insert_block(root, world_pos, block, 0)

func remove_chunk(chunk_pos: Vector3i, chunk_size: int = 16):
	var start_pos = Vector3(chunk_pos * chunk_size)
	var chunk_bounds = AABB(start_pos, Vector3(chunk_size, chunk_size, chunk_size))
	_remove_region(root, chunk_bounds)

func is_solid_at(pos: Vector3) -> bool:
	return _query_solid(root, pos)

func get_block_at(pos: Vector3) -> int:
	return _query_block(root, pos)

func raycast(origin: Vector3, direction: Vector3, max_distance: float = 100.0) -> Dictionary:
	var result = {
		"hit": false,
		"position": Vector3.ZERO,
		"normal": Vector3.ZERO,
		"block_type": Block.BlockType.AIR,
		"distance": max_distance
	}

	var dir_normalized = direction.normalized()
	var current = origin
	var step = 0.1  
	var distance = 0.0

	while distance < max_distance:

		if is_solid_at(current):
			result.hit = true
			result.position = current.floor()
			result.block_type = get_block_at(current)
			result.distance = distance

			var block_center = result.position + Vector3(0.5, 0.5, 0.5)
			var to_center = current - block_center
			var abs_diff = Vector3(abs(to_center.x), abs(to_center.y), abs(to_center.z))

			if abs_diff.x > abs_diff.y and abs_diff.x > abs_diff.z:
				result.normal = Vector3(sign(to_center.x), 0, 0)
			elif abs_diff.y > abs_diff.z:
				result.normal = Vector3(0, sign(to_center.y), 0)
			else:
				result.normal = Vector3(0, 0, sign(to_center.z))

			return result

		current += dir_normalized * step
		distance += step

	return result

func check_collision(aabb: AABB) -> bool:
	return _check_aabb_collision(root, aabb)

func query_region(aabb: AABB) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	_query_region_recursive(root, aabb, results)
	return results

func _insert_block(node: OctreeNode, pos: Vector3, block_type: int, depth: int):
	if not node.bounds.has_point(pos):
		return

	node.is_empty = false

	if node.is_leaf and node.bounds.size.x > MIN_NODE_SIZE and depth < MAX_DEPTH:
		node.subdivide()

	if not node.is_leaf:

		var child_idx = node.get_child_index(pos)
		_insert_block(node.children[child_idx], pos, block_type, depth + 1)

		_update_node_status(node)
	else:

		node.is_solid = true
		node.block_type = block_type

func _query_solid(node: OctreeNode, pos: Vector3) -> bool:
	if not node.bounds.has_point(pos):
		return false

	if node.is_empty:
		return false

	if node.is_solid and node.is_leaf:
		return true

	if not node.is_leaf:
		var child_idx = node.get_child_index(pos)
		return _query_solid(node.children[child_idx], pos)

	return false

func _query_block(node: OctreeNode, pos: Vector3) -> int:
	if not node.bounds.has_point(pos):
		return Block.BlockType.AIR

	if node.is_empty:
		return Block.BlockType.AIR

	if node.is_solid and node.is_leaf:
		return node.block_type if node.block_type >= 0 else Block.BlockType.STONE

	if not node.is_leaf:
		var child_idx = node.get_child_index(pos)
		return _query_block(node.children[child_idx], pos)

	return Block.BlockType.AIR

func _check_aabb_collision(node: OctreeNode, aabb: AABB) -> bool:
	if not node.bounds.intersects(aabb):
		return false

	if node.is_empty:
		return false

	if node.is_solid and node.is_leaf:
		return true

	if not node.is_leaf:
		for child in node.children:
			if _check_aabb_collision(child, aabb):
				return true

	return false

func _query_region_recursive(node: OctreeNode, aabb: AABB, results: Array[Vector3i]):
	if not node.bounds.intersects(aabb):
		return

	if node.is_empty:
		return

	if node.is_solid and node.is_leaf:

		var min_pos = Vector3i(
			max(int(node.bounds.position.x), int(aabb.position.x)),
			max(int(node.bounds.position.y), int(aabb.position.y)),
			max(int(node.bounds.position.z), int(aabb.position.z))
		)
		var max_pos = Vector3i(
			min(int(node.bounds.end.x), int(aabb.end.x)),
			min(int(node.bounds.end.y), int(aabb.end.y)),
			min(int(node.bounds.end.z), int(aabb.end.z))
		)

		for x in range(min_pos.x, max_pos.x):
			for y in range(min_pos.y, max_pos.y):
				for z in range(min_pos.z, max_pos.z):
					results.append(Vector3i(x, y, z))
		return

	if not node.is_leaf:
		for child in node.children:
			_query_region_recursive(child, aabb, results)

func _remove_region(node: OctreeNode, aabb: AABB):
	if not node.bounds.intersects(aabb):
		return

	if aabb.encloses(node.bounds):
		node.is_empty = true
		node.is_solid = false
		node.is_leaf = true
		node.children.clear()
		return

	if not node.is_leaf:
		for child in node.children:
			_remove_region(child, aabb)
		_update_node_status(node)

func _update_node_status(node: OctreeNode):
	if node.is_leaf:
		return

	var all_empty = true
	var all_solid = true
	var same_block_type = true
	var first_block_type = -1

	for child in node.children:
		if not child.is_empty:
			all_empty = false
		if not child.is_solid or not child.is_leaf:
			all_solid = false

		if child.is_solid and first_block_type == -1:
			first_block_type = child.block_type
		elif child.block_type != first_block_type:
			same_block_type = false

	if all_empty:
		node.is_empty = true
		node.is_solid = false
		node.is_leaf = true
		node.children.clear()

	elif all_solid and same_block_type:
		node.is_solid = true
		node.is_leaf = true
		node.block_type = first_block_type
		node.children.clear()
	else:
		node.is_empty = false
		node.is_solid = false

func get_stats() -> Dictionary:
	var stats = {
		"total_nodes": 0,
		"leaf_nodes": 0,
		"empty_nodes": 0,
		"solid_nodes": 0,
		"max_depth_reached": 0
	}
	_collect_stats(root, stats, 0)
	return stats

func _collect_stats(node: OctreeNode, stats: Dictionary, depth: int):
	stats.total_nodes += 1
	stats.max_depth_reached = max(stats.max_depth_reached, depth)

	if node.is_leaf:
		stats.leaf_nodes += 1
	if node.is_empty:
		stats.empty_nodes += 1
	if node.is_solid:
		stats.solid_nodes += 1

	if not node.is_leaf:
		for child in node.children:
			_collect_stats(child, stats, depth + 1)
