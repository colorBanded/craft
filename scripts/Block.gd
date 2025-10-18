class_name Block
extends RefCounted

enum BlockType {
	AIR = 0,
	DIRT = 1,
	GRASS = 2,
	STONE = 3,
	WOOD = 4,
	SAND = 5,
	WATER = 6,
	GRAVEL = 7,
	COBBLESTONE = 8,
	PLANKS = 9,
}

static var BLOCK_TEXTURES = {
	BlockType.DIRT: Vector2i(2, 0),
	BlockType.GRASS: {
		"top": Vector2i(0, 0),
		"bottom": Vector2i(2, 0),
		"side": Vector2i(3, 0)
	},
	BlockType.STONE: Vector2i(1, 0),
	BlockType.SAND: Vector2i(2, 1),
	BlockType.GRAVEL: Vector2i(3, 1),
	BlockType.COBBLESTONE: Vector2i(0, 1),
	BlockType.WOOD: {
		"top": Vector2i(5, 1),
		"bottom": Vector2i(5, 1),
		"side": Vector2i(4, 1)
	},
	BlockType.PLANKS: Vector2i(4, 0),
	BlockType.WATER: Vector2i(15, 12),  
}

const ATLAS_SIZE = Vector2i(16, 16)

static func is_transparent(block_type: int) -> bool:
	return block_type == BlockType.AIR or block_type == BlockType.WATER

static func is_solid(block_type: int) -> bool:
	return block_type != BlockType.AIR and block_type != BlockType.WATER
