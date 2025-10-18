class_name ChunkData
extends RefCounted

const CHUNK_SIZE = 16

var blocks: PackedByteArray  
var light_data: PackedByteArray  
var position: Vector3i       
var is_generated: bool = false
var is_modified: bool = false
var needs_light_update: bool = true

func _init(pos: Vector3i):
	position = pos
	blocks.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	blocks.fill(0)
	light_data.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	light_data.fill(0)  

func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return Block.BlockType.AIR
	var index = x + z * CHUNK_SIZE + y * CHUNK_SIZE * CHUNK_SIZE
	return blocks[index]

func set_block(x: int, y: int, z: int, block_type: int):
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return
	var index = x + z * CHUNK_SIZE + y * CHUNK_SIZE * CHUNK_SIZE
	if blocks[index] != block_type:
		blocks[index] = block_type
		is_modified = true
		needs_light_update = true

func is_empty() -> bool:
	for i in blocks.size():
		if blocks[i] != Block.BlockType.AIR:
			return false
	return true

func get_block_count() -> int:
	var count = 0
	for i in blocks.size():
		if blocks[i] != Block.BlockType.AIR:
			count += 1
	return count

func get_sunlight(x: int, y: int, z: int) -> int:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return 0
	var index = x + z * CHUNK_SIZE + y * CHUNK_SIZE * CHUNK_SIZE
	return (light_data[index] >> 4) & 0xF

func get_block_light(x: int, y: int, z: int) -> int:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return 0
	var index = x + z * CHUNK_SIZE + y * CHUNK_SIZE * CHUNK_SIZE
	return light_data[index] & 0xF

func get_light(x: int, y: int, z: int) -> int:
	return max(get_sunlight(x, y, z), get_block_light(x, y, z))

func set_sunlight(x: int, y: int, z: int, level: int):
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return
	var index = x + z * CHUNK_SIZE + y * CHUNK_SIZE * CHUNK_SIZE
	var block_light = light_data[index] & 0xF
	light_data[index] = (clampi(level, 0, 15) << 4) | block_light

func set_block_light(x: int, y: int, z: int, level: int):
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return
	var index = x + z * CHUNK_SIZE + y * CHUNK_SIZE * CHUNK_SIZE
	var sunlight = (light_data[index] >> 4) & 0xF
	light_data[index] = (sunlight << 4) | clampi(level, 0, 15)
