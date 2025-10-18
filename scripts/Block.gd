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

static var BLOCK_OVERLAYS = {
	BlockType.GRASS: {
		"side": Vector2i(6, 2)
	}
}

static var BLOCK_LIGHT_LEVELS = {

}

const ATLAS_SIZE = Vector2i(16, 16)

static func is_transparent(block_type: int) -> bool:
	return block_type == BlockType.AIR or block_type == BlockType.WATER

static func is_solid(block_type: int) -> bool:
	return block_type != BlockType.AIR and block_type != BlockType.WATER

static func get_overlay(block_type: int, face: String) -> Vector2i:
	if block_type in BLOCK_OVERLAYS:
		var overlay_data = BLOCK_OVERLAYS[block_type]
		if overlay_data is Dictionary:
			return overlay_data.get(face, Vector2i(-1, -1))
	return Vector2i(-1, -1)

static func get_light_emission(block_type: int) -> int:
	return BLOCK_LIGHT_LEVELS.get(block_type, 0)
