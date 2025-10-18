extends Sprite2D
class_name Hotbar

@export var slot_count: int = 9
@export var selected_slot: int = 0

var hotbar_blocks: Array[int] = [
	Block.BlockType.GRASS,
	Block.BlockType.DIRT,
	Block.BlockType.STONE,
	Block.BlockType.WOOD,
	Block.BlockType.SAND,
	Block.BlockType.COBBLESTONE,
	Block.BlockType.GRAVEL,
	Block.BlockType.PLANKS,
	Block.BlockType.AIR  
]

signal slot_changed(slot_index: int, block_type: int)

func _ready():
	_update_selection_visual()
	emit_signal("slot_changed", selected_slot, hotbar_blocks[selected_slot])

func _input(event):

	if event is InputEventKey and event.pressed and not event.echo:
		for i in range(1, 10):
			if event.keycode == KEY_1 + (i - 1):
				select_slot(i - 1)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				select_previous_slot()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				select_next_slot()
				get_viewport().set_input_as_handled()

func select_slot(index: int):
	if index >= 0 and index < slot_count:
		selected_slot = index
		_update_selection_visual()
		emit_signal("slot_changed", selected_slot, hotbar_blocks[selected_slot])

func select_next_slot():
	select_slot((selected_slot + 1) % slot_count)

func select_previous_slot():
	select_slot((selected_slot - 1 + slot_count) % slot_count)

func get_selected_block() -> int:
	return hotbar_blocks[selected_slot]

func set_slot_block(slot_index: int, block_type: int):
	if slot_index >= 0 and slot_index < hotbar_blocks.size():
		hotbar_blocks[slot_index] = block_type

func _update_selection_visual():

	var selected_highlight = get_node_or_null("../Selected")

	if selected_highlight:

		var slot_width = 20  
		var outline = 1      
		var selector_offset = 2  
		var horizontal_adjust = 12 

		var hotbar_half_width = 91  
		var start_x = -hotbar_half_width + outline

		var x_position = start_x + (selected_slot * slot_width) - selector_offset + horizontal_adjust

		selected_highlight.position.x = x_position
		selected_highlight.position.y = 0  

	for i in range(slot_count):
		var slot = get_node_or_null("Slot" + str(i))
		if slot:
			if i == selected_slot:
				slot.modulate = Color(1.5, 1.5, 1.5, 1.0)  
			else:
				slot.modulate = Color(1.0, 1.0, 1.0, 1.0)  

func get_block_name(block_type: int) -> String:
	match block_type:
		Block.BlockType.AIR: return "Air"
		Block.BlockType.GRASS: return "Grass"
		Block.BlockType.DIRT: return "Dirt"
		Block.BlockType.STONE: return "Stone"
		Block.BlockType.WOOD: return "Wood"
		Block.BlockType.SAND: return "Sand"
		Block.BlockType.COBBLESTONE: return "Cobblestone"
		Block.BlockType.GRAVEL: return "Gravel"
		Block.BlockType.PLANKS: return "Planks"
		_: return "Unknown"
