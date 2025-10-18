class_name ChunkData
extends RefCounted

const CHUNK_SIZE = 16

var blocks: PackedByteArray  
var position: Vector3i       
var is_generated: bool = false
var is_modified: bool = false

func _init(pos: Vector3i):
	position = pos
	blocks.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	blocks.fill(0)  

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
