extends Node3D

const CHUNK_SIZE = 16
const RENDER_DISTANCE = 4  
const WORLD_HEIGHT_CHUNKS = 1  

var chunk_data: Dictionary = {}  

var chunk_nodes: Dictionary = {}  

var player: CharacterBody3D
var last_player_chunk: Vector3i = Vector3i(999999, 999999, 999999)
var debug_manual_loading: bool = false  

func _ready():

	player = get_node_or_null("../playerchar")
	if player == null:
		push_error("Player node 'playerchar' not found! Make sure it exists in the scene.")
		return

	print("Generating world terrain...")
	_generate_initial_terrain()
	print("Terrain generated! Total chunks: ", chunk_data.size())
	print("Press L to manually load chunks, or M to toggle auto-loading")

	if not debug_manual_loading:
		_update_chunks()

func _process(_delta):
	if player == null:
		return

	if Input.is_physical_key_pressed(KEY_L):
		print("Manual chunk load triggered!")
		_update_chunks()
		await get_tree().create_timer(0.2).timeout  

	if Input.is_action_just_pressed("debug_toggle_autoload"):  
		debug_manual_loading = !debug_manual_loading
		print("=== Auto-loading: ", "OFF" if debug_manual_loading else "ON", " ===")

	var current_chunk = _world_to_chunk(player.global_position)

	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		if not debug_manual_loading:
			_update_chunks()

func _world_to_chunk(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / CHUNK_SIZE),
		floori(world_pos.y / CHUNK_SIZE),
		floori(world_pos.z / CHUNK_SIZE)
	)

func _generate_initial_terrain():

	for x in range(-RENDER_DISTANCE - 2, RENDER_DISTANCE + 3):
		for z in range(-RENDER_DISTANCE - 2, RENDER_DISTANCE + 3):
			for y in range(0, WORLD_HEIGHT_CHUNKS):
				var chunk_pos = Vector3i(x, y, z)
				var data = ChunkData.new(chunk_pos)

				_generate_chunk_terrain(data, chunk_pos)

				data.is_generated = true
				chunk_data[chunk_pos] = data

func _generate_chunk_terrain(data: ChunkData, chunk_pos: Vector3i):

	var blocks_set = 0
	for bx in CHUNK_SIZE:
		for bz in CHUNK_SIZE:

			var world_x = chunk_pos.x * CHUNK_SIZE + bx
			var world_z = chunk_pos.z * CHUNK_SIZE + bz

			var height = 5 + int(sin(world_x * 0.1) * 3 + cos(world_z * 0.1) * 3)

			var chunk_y_start = chunk_pos.y * CHUNK_SIZE
			var chunk_y_end = chunk_y_start + CHUNK_SIZE

			for world_y in range(max(0, chunk_y_start), min(height, chunk_y_end)):
				var local_y = world_y - chunk_y_start

				if world_y == 0:

					data.set_block(bx, local_y, bz, Block.BlockType.STONE)
					blocks_set += 1
				elif world_y < height - 1:

					data.set_block(bx, local_y, bz, Block.BlockType.DIRT)
					blocks_set += 1
				elif world_y == height - 1:

					data.set_block(bx, local_y, bz, Block.BlockType.GRASS)
					blocks_set += 1

	if chunk_pos == Vector3i(0, 0, 0):
		print("  Generated chunk (0,0,0): ", blocks_set, " blocks placed")

		print("    Block at (0,0,0): ", data.get_block(0, 0, 0))
		print("    Block at (0,5,0): ", data.get_block(0, 5, 0))
		print("    Block at (0,10,0): ", data.get_block(0, 10, 0))

func _update_chunks():
	if player == null:
		return

	var player_chunk = last_player_chunk
	var chunks_to_load: Array[Vector3i] = []
	var chunks_to_unload: Array[Vector3i] = []

	for x in range(player_chunk.x - RENDER_DISTANCE, player_chunk.x + RENDER_DISTANCE + 1):
		for z in range(player_chunk.z - RENDER_DISTANCE, player_chunk.z + RENDER_DISTANCE + 1):
			for y in range(0, WORLD_HEIGHT_CHUNKS):
				var chunk_pos = Vector3i(x, y, z)

				if chunk_pos in chunk_data and chunk_pos not in chunk_nodes:
					chunks_to_load.append(chunk_pos)

	for chunk_pos in chunk_nodes.keys():
		var distance_xz = max(
			abs(chunk_pos.x - player_chunk.x),
			abs(chunk_pos.z - player_chunk.z)
		)
		if distance_xz > RENDER_DISTANCE + 1:
			chunks_to_unload.append(chunk_pos)

	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)

	for chunk_pos in chunks_to_load:
		_load_chunk(chunk_pos)

	if chunks_to_load.size() > 0 or chunks_to_unload.size() > 0:
		print(">>> Chunks loaded: %d, unloaded: %d, total active: %d" % [
			chunks_to_load.size(),
			chunks_to_unload.size(),
			chunk_nodes.size()
		])
		print("    Player at chunk: ", last_player_chunk)

func _load_chunk(chunk_pos: Vector3i):
	if chunk_pos not in chunk_data:
		print("  ! Cannot load chunk at ", chunk_pos, " - no data exists")
		return

	if chunk_pos in chunk_nodes:
		return  

	print("  + Loading chunk at ", chunk_pos)
	var data = chunk_data[chunk_pos]
	var chunk = Chunk.new(data)

	add_child(chunk)
	chunk_nodes[chunk_pos] = chunk

	var neighbors = {}
	for offset in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]:
		var neighbor_pos = chunk_pos + offset
		if neighbor_pos in chunk_data:
			neighbors[neighbor_pos] = chunk_data[neighbor_pos]

	chunk.generate_mesh(neighbors)

func _unload_chunk(chunk_pos: Vector3i):
	if chunk_pos not in chunk_nodes:
		return

	var chunk = chunk_nodes[chunk_pos]
	chunk_nodes.erase(chunk_pos)
	chunk.queue_free()

func get_block_at_world_pos(world_pos: Vector3) -> int:
	var chunk_pos = _world_to_chunk(world_pos)

	if chunk_pos not in chunk_data:
		return Block.BlockType.AIR

	var data = chunk_data[chunk_pos]
	var local_pos = Vector3i(
		posmod(int(world_pos.x), CHUNK_SIZE),
		posmod(int(world_pos.y), CHUNK_SIZE),
		posmod(int(world_pos.z), CHUNK_SIZE)
	)

	return data.get_block(local_pos.x, local_pos.y, local_pos.z)

func set_block_at_world_pos(world_pos: Vector3, block_type: int):
	var chunk_pos = _world_to_chunk(world_pos)

	if chunk_pos not in chunk_data:
		return

	var data = chunk_data[chunk_pos]
	var local_pos = Vector3i(
		posmod(int(world_pos.x), CHUNK_SIZE),
		posmod(int(world_pos.y), CHUNK_SIZE),
		posmod(int(world_pos.z), CHUNK_SIZE)
	)

	data.set_block(local_pos.x, local_pos.y, local_pos.z, block_type)

	if chunk_pos in chunk_nodes:
		var neighbors = {}
		for offset in [
			Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0), Vector3i(0, -1, 0),
			Vector3i(0, 0, 1), Vector3i(0, 0, -1)
		]:
			var neighbor_pos = chunk_pos + offset
			if neighbor_pos in chunk_data:
				neighbors[neighbor_pos] = chunk_data[neighbor_pos]

		chunk_nodes[chunk_pos].generate_mesh(neighbors)
