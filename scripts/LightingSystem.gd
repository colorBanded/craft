class_name LightingSystem
extends RefCounted

const CHUNK_SIZE = 16
const MAX_LIGHT_LEVEL = 15

var world: Node  
var light_update_queue: Array[Dictionary] = []  

func _init(world_node: Node):
	world = world_node

func calculate_sunlight(chunk_data: ChunkData, neighbor_chunks: Dictionary):

	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var light_level = MAX_LIGHT_LEVEL

			var chunk_above_pos = chunk_data.position + Vector3i(0, 1, 0)
			if chunk_above_pos in neighbor_chunks:
				var chunk_above = neighbor_chunks[chunk_above_pos]

				light_level = chunk_above.get_sunlight(x, 0, z)

			elif chunk_data.position.y < 0:
				light_level = 0

			for y in range(CHUNK_SIZE - 1, -1, -1):
				var block = chunk_data.get_block(x, y, z)

				if Block.is_transparent(block):
					chunk_data.set_sunlight(x, y, z, light_level)

					if light_level > 0:
						light_level = max(0, light_level - 1)
				else:
					chunk_data.set_sunlight(x, y, z, 0)
					light_level = 0  

	chunk_data.needs_light_update = false

func _propagate_horizontal_sunlight(chunk_data: ChunkData, neighbor_chunks: Dictionary):
	var light_queue: Array[Dictionary] = []  

	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var light = chunk_data.get_sunlight(x, y, z)
				if light > 0:

					if x == 0 or x == CHUNK_SIZE - 1 or z == 0 or z == CHUNK_SIZE - 1:
						light_queue.append({"pos": Vector3i(x, y, z), "level": light})

	var processed = {}
	while light_queue.size() > 0:
		var entry = light_queue.pop_front()
		var pos: Vector3i = entry.pos
		var level: int = entry.level

		var key = "%d,%d,%d" % [pos.x, pos.y, pos.z]
		if key in processed:
			continue
		processed[key] = true

		if level <= 1:
			continue

		var new_level = level - 1

		var neighbors = [
			Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
			Vector3i(0, 0, 1), Vector3i(0, 0, -1)
		]

		for offset in neighbors:
			var neighbor_pos = pos + offset

			var block = _get_block_with_neighbors(chunk_data, neighbor_pos, neighbor_chunks)
			var current_light = _get_sunlight_with_neighbors(chunk_data, neighbor_pos, neighbor_chunks)

			if Block.is_transparent(block) and new_level > current_light:
				_set_sunlight_with_neighbors(chunk_data, neighbor_pos, neighbor_chunks, new_level)
				light_queue.append({"pos": neighbor_pos, "level": new_level})

func propagate_block_light(chunk_data: ChunkData, neighbor_chunks: Dictionary):
	var light_queue: Array[Dictionary] = []  

	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var block = chunk_data.get_block(x, y, z)
				var emission = Block.get_light_emission(block)

				if emission > 0:
					chunk_data.set_block_light(x, y, z, emission)
					light_queue.append({"pos": Vector3i(x, y, z), "level": emission})

	while light_queue.size() > 0:
		var entry = light_queue.pop_front()
		var pos: Vector3i = entry.pos
		var level: int = entry.level

		if level <= 1:
			continue

		var new_level = level - 1

		var neighbors = [
			Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0), Vector3i(0, -1, 0),
			Vector3i(0, 0, 1), Vector3i(0, 0, -1)
		]

		for offset in neighbors:
			var neighbor_pos = pos + offset

			var block: int
			var current_light: int

			if _is_in_chunk(neighbor_pos):
				block = chunk_data.get_block(neighbor_pos.x, neighbor_pos.y, neighbor_pos.z)
				current_light = chunk_data.get_block_light(neighbor_pos.x, neighbor_pos.y, neighbor_pos.z)
			else:

				continue

			if Block.is_transparent(block) and new_level > current_light:
				if _is_in_chunk(neighbor_pos):
					chunk_data.set_block_light(neighbor_pos.x, neighbor_pos.y, neighbor_pos.z, new_level)
					light_queue.append({"pos": neighbor_pos, "level": new_level})

func _is_in_chunk(pos: Vector3i) -> bool:
	return pos.x >= 0 and pos.x < CHUNK_SIZE and \
		   pos.y >= 0 and pos.y < CHUNK_SIZE and \
		   pos.z >= 0 and pos.z < CHUNK_SIZE

func _get_block_with_neighbors(chunk_data: ChunkData, pos: Vector3i, neighbor_chunks: Dictionary) -> int:
	if _is_in_chunk(pos):
		return chunk_data.get_block(pos.x, pos.y, pos.z)

	var chunk_offset = Vector3i(
		floori(float(pos.x) / CHUNK_SIZE),
		floori(float(pos.y) / CHUNK_SIZE),
		floori(float(pos.z) / CHUNK_SIZE)
	)
	var neighbor_pos = chunk_data.position + chunk_offset

	if neighbor_pos in neighbor_chunks:
		var local_pos = Vector3i(
			posmod(pos.x, CHUNK_SIZE),
			posmod(pos.y, CHUNK_SIZE),
			posmod(pos.z, CHUNK_SIZE)
		)
		return neighbor_chunks[neighbor_pos].get_block(local_pos.x, local_pos.y, local_pos.z)

	return Block.BlockType.AIR

func _get_sunlight_with_neighbors(chunk_data: ChunkData, pos: Vector3i, neighbor_chunks: Dictionary) -> int:
	if _is_in_chunk(pos):
		return chunk_data.get_sunlight(pos.x, pos.y, pos.z)

	var chunk_offset = Vector3i(
		floori(float(pos.x) / CHUNK_SIZE),
		floori(float(pos.y) / CHUNK_SIZE),
		floori(float(pos.z) / CHUNK_SIZE)
	)
	var neighbor_pos = chunk_data.position + chunk_offset

	if neighbor_pos in neighbor_chunks:
		var local_pos = Vector3i(
			posmod(pos.x, CHUNK_SIZE),
			posmod(pos.y, CHUNK_SIZE),
			posmod(pos.z, CHUNK_SIZE)
		)
		return neighbor_chunks[neighbor_pos].get_sunlight(local_pos.x, local_pos.y, local_pos.z)

	return 0

func _set_sunlight_with_neighbors(chunk_data: ChunkData, pos: Vector3i, neighbor_chunks: Dictionary, level: int):
	if _is_in_chunk(pos):
		chunk_data.set_sunlight(pos.x, pos.y, pos.z, level)
		return

	var chunk_offset = Vector3i(
		floori(float(pos.x) / CHUNK_SIZE),
		floori(float(pos.y) / CHUNK_SIZE),
		floori(float(pos.z) / CHUNK_SIZE)
	)
	var neighbor_pos = chunk_data.position + chunk_offset

	if neighbor_pos in neighbor_chunks:
		var local_pos = Vector3i(
			posmod(pos.x, CHUNK_SIZE),
			posmod(pos.y, CHUNK_SIZE),
			posmod(pos.z, CHUNK_SIZE)
		)
		neighbor_chunks[neighbor_pos].set_sunlight(local_pos.x, local_pos.y, local_pos.z, level)

static func get_vertex_light(chunk_data: ChunkData, pos: Vector3, neighbor_chunks: Dictionary) -> float:

	var x = floori(pos.x)
	var y = floori(pos.y)
	var z = floori(pos.z)

	var total_light = 0.0
	var samples = 0

	var offsets = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(1, 0, 1)
	]

	for offset in offsets:
		var sample_pos = Vector3i(x, y, z) + offset
		var light = _get_light_with_neighbors(chunk_data, sample_pos, neighbor_chunks)
		total_light += light
		samples += 1

	return total_light / float(max(1, samples))

static func _get_light_with_neighbors(chunk_data: ChunkData, pos: Vector3i, neighbor_chunks: Dictionary) -> int:
	if pos.x >= 0 and pos.x < CHUNK_SIZE and \
	   pos.y >= 0 and pos.y < CHUNK_SIZE and \
	   pos.z >= 0 and pos.z < CHUNK_SIZE:
		return chunk_data.get_light(pos.x, pos.y, pos.z)

	var chunk_offset = Vector3i(
		floori(float(pos.x) / CHUNK_SIZE),
		floori(float(pos.y) / CHUNK_SIZE),
		floori(float(pos.z) / CHUNK_SIZE)
	)
	var neighbor_pos = chunk_data.position + chunk_offset

	if neighbor_pos in neighbor_chunks:
		var local_pos = Vector3i(
			posmod(pos.x, CHUNK_SIZE),
			posmod(pos.y, CHUNK_SIZE),
			posmod(pos.z, CHUNK_SIZE)
		)
		return neighbor_chunks[neighbor_pos].get_light(local_pos.x, local_pos.y, local_pos.z)

	return MAX_LIGHT_LEVEL  
