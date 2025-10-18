class_name Chunk
extends Node3D

const CHUNK_SIZE = 16
const BLOCK_SIZE = 1.0

var chunk_data: ChunkData  
var mesh_instance: MeshInstance3D
var chunk_position: Vector3i

func _init(data: ChunkData):
	chunk_data = data
	chunk_position = data.position
	name = "Chunk_%d_%d_%d" % [chunk_position.x, chunk_position.y, chunk_position.z]

	position = Vector3(chunk_position) * CHUNK_SIZE * BLOCK_SIZE

func generate_mesh(neighbor_chunks: Dictionary = {}):
	if chunk_data.is_empty():
		return  

	if _is_completely_occluded(neighbor_chunks):
		print("  - Chunk ", chunk_position, ": completely occluded, skipping mesh")
		if mesh_instance != null:
			mesh_instance.mesh = null  
		return

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var block_count = 0

	_greedy_mesh_chunk(surface_tool, neighbor_chunks)

	for x in CHUNK_SIZE:
		for y in CHUNK_SIZE:
			for z in CHUNK_SIZE:
				if not Block.is_transparent(chunk_data.get_block(x, y, z)):
					block_count += 1

	surface_tool.generate_normals()

	var array_mesh = surface_tool.commit()

	if array_mesh.get_surface_count() == 0:
		print("  - Chunk ", chunk_position, ": no visible faces (", block_count, " blocks)")
		return  

	var vertex_count = array_mesh.surface_get_array_len(0)
	var face_count = vertex_count / 6  

	print("  - Chunk ", chunk_position, ": ", block_count, " blocks, ", face_count, " faces (greedy meshed)")

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)

		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/block_atlas.gdshader")
		material.set_shader_parameter("atlas_texture", load("res://textures/default/terrain.png"))
		material.set_shader_parameter("atlas_size", float(Block.ATLAS_SIZE.x))
		mesh_instance.material_override = material

	mesh_instance.mesh = array_mesh

func _greedy_mesh_chunk(surface_tool: SurfaceTool, neighbor_chunks: Dictionary):

	_greedy_mesh_axis(surface_tool, Vector3i.UP, "top", neighbor_chunks)      
	_greedy_mesh_axis(surface_tool, Vector3i.DOWN, "bottom", neighbor_chunks)  
	_greedy_mesh_axis(surface_tool, Vector3i.RIGHT, "side", neighbor_chunks)   
	_greedy_mesh_axis(surface_tool, Vector3i.LEFT, "side", neighbor_chunks)    
	_greedy_mesh_axis(surface_tool, Vector3i.BACK, "side", neighbor_chunks)    
	_greedy_mesh_axis(surface_tool, Vector3i.FORWARD, "side", neighbor_chunks) 

func _greedy_mesh_axis(surface_tool: SurfaceTool, direction: Vector3i, face_type: String, neighbor_chunks: Dictionary):

	var axis_d = 0  
	var axis_u = 1  
	var axis_v = 2  

	if abs(direction.x) > 0:
		axis_d = 0
		axis_u = 2
		axis_v = 1
	elif abs(direction.y) > 0:
		axis_d = 1
		axis_u = 0
		axis_v = 2
	else:  
		axis_d = 2
		axis_u = 0
		axis_v = 1

	var mask: Array = []
	mask.resize(CHUNK_SIZE * CHUNK_SIZE)

	for d in range(CHUNK_SIZE):

		mask.fill(null)

		for v in range(CHUNK_SIZE):
			for u in range(CHUNK_SIZE):

				var pos = Vector3i.ZERO
				pos[axis_d] = d
				pos[axis_u] = u
				pos[axis_v] = v

				var block_type = chunk_data.get_block(pos.x, pos.y, pos.z)
				if Block.is_transparent(block_type):
					continue

				var neighbor_pos = pos + direction
				var neighbor_type = _get_block_with_neighbors(neighbor_pos, neighbor_chunks)

				if Block.is_transparent(neighbor_type):

					mask[u + v * CHUNK_SIZE] = block_type

		_greedy_mesh_slice(surface_tool, mask, d, direction, axis_d, axis_u, axis_v, face_type, neighbor_chunks)

func _greedy_mesh_slice(surface_tool: SurfaceTool, mask: Array, depth: int, direction: Vector3i, axis_d: int, axis_u: int, axis_v: int, face_type: String, neighbor_chunks: Dictionary):
	for v in range(CHUNK_SIZE):
		for u in range(CHUNK_SIZE):
			var block_type = mask[u + v * CHUNK_SIZE]

			if block_type == null:
				continue

			var width = 1
			while u + width < CHUNK_SIZE and mask[u + width + v * CHUNK_SIZE] == block_type:
				width += 1

			var height = 1
			var done = false
			while v + height < CHUNK_SIZE and not done:
				for du in range(width):
					if mask[u + du + (v + height) * CHUNK_SIZE] != block_type:
						done = true
						break
				if not done:
					height += 1

			var pos_3d = Vector3i.ZERO
			pos_3d[axis_d] = depth
			pos_3d[axis_u] = u
			pos_3d[axis_v] = v

			_add_greedy_quad(surface_tool, pos_3d, width, height, direction, axis_u, axis_v, block_type, face_type, neighbor_chunks)

			for dv in range(height):
				for du in range(width):
					mask[u + du + (v + dv) * CHUNK_SIZE] = null

func _add_greedy_quad(surface_tool: SurfaceTool, pos: Vector3i, width: int, height: int, normal: Vector3i, axis_u: int, axis_v: int, block_type: int, face_type: String, neighbor_chunks: Dictionary):
	var base = Vector3(pos)

	if normal.x > 0 or normal.y > 0 or normal.z > 0:
		base += Vector3(normal)

	var du = Vector3.ZERO
	du[axis_u] = float(width)

	var dv = Vector3.ZERO
	dv[axis_v] = float(height)

	var uv_offset = _get_block_uv(block_type, face_type)
	var overlay_offset = Block.get_overlay(block_type, face_type)

	var verts: Array
	var uvs: Array  
	var atlas_uvs: Array  

	var atlas_pos = Vector2(uv_offset)
	var overlay_pos = Vector2(overlay_offset)

	if normal == Vector3i.UP:  
		verts = [
			base,
			base + du,
			base + du + dv,
			base + dv
		]
		uvs = [
			Vector2(0, 0),
			Vector2(float(width), 0),
			Vector2(float(width), float(height)),
			Vector2(0, float(height))
		]
		atlas_uvs = [atlas_pos, atlas_pos, atlas_pos, atlas_pos]
	elif normal == Vector3i.DOWN:  
		verts = [
			base,
			base + dv,
			base + du + dv,
			base + du
		]
		uvs = [
			Vector2(0, 0),
			Vector2(0, float(height)),
			Vector2(float(width), float(height)),
			Vector2(float(width), 0)
		]
		atlas_uvs = [atlas_pos, atlas_pos, atlas_pos, atlas_pos]
	elif normal == Vector3i.RIGHT:  
		verts = [
			base + du + dv,
			base + dv,
			base,
			base + du
		]
		uvs = [
			Vector2(0, 0),
			Vector2(float(width), 0),
			Vector2(float(width), float(height)),
			Vector2(0, float(height))
		]
		atlas_uvs = [atlas_pos, atlas_pos, atlas_pos, atlas_pos]
	elif normal == Vector3i.LEFT:  
		verts = [
			base + du + dv,
			base + du,
			base,
			base + dv
		]
		uvs = [
			Vector2(0, 0),
			Vector2(0, float(height)),
			Vector2(float(width), float(height)),
			Vector2(float(width), 0)
		]
		atlas_uvs = [atlas_pos, atlas_pos, atlas_pos, atlas_pos]
	elif normal == Vector3i.BACK:  
		verts = [
			base + du + dv,
			base + du,
			base,
			base + dv
		]
		uvs = [
			Vector2(0, 0),
			Vector2(0, float(height)),
			Vector2(float(width), float(height)),
			Vector2(float(width), 0)
		]
		atlas_uvs = [atlas_pos, atlas_pos, atlas_pos, atlas_pos]
	else:  
		verts = [
			base + du + dv,
			base + dv,
			base,
			base + du
		]
		uvs = [
			Vector2(0, 0),
			Vector2(float(width), 0),
			Vector2(float(width), float(height)),
			Vector2(0, float(height))
		]
		atlas_uvs = [atlas_pos, atlas_pos, atlas_pos, atlas_pos]

	var light_sample_pos = pos + normal  
	var light_level = _get_face_light(light_sample_pos, neighbor_chunks)

	var compressed_level = floori(light_level)  
	var brightness = compressed_level / 15.0  

	var indices = [0, 1, 2, 0, 2, 3]
	for i in indices:
		surface_tool.set_uv(uvs[i])
		surface_tool.set_uv2(atlas_uvs[i])

		surface_tool.set_color(Color(
			(overlay_pos.x + 1.0) / 17.0,
			(overlay_pos.y + 1.0) / 17.0,
			brightness,
			1.0
		))
		surface_tool.add_vertex(verts[i])

func _get_block_with_neighbors(pos: Vector3i, neighbor_chunks: Dictionary) -> int:

	if pos.x >= 0 and pos.x < CHUNK_SIZE and pos.y >= 0 and pos.y < CHUNK_SIZE and pos.z >= 0 and pos.z < CHUNK_SIZE:
		return chunk_data.get_block(pos.x, pos.y, pos.z)

	var chunk_offset = Vector3i(
		floori(float(pos.x) / CHUNK_SIZE),
		floori(float(pos.y) / CHUNK_SIZE),
		floori(float(pos.z) / CHUNK_SIZE)
	)

	var neighbor_pos = chunk_position + chunk_offset
	if neighbor_pos in neighbor_chunks:
		var local_pos = Vector3i(
			posmod(pos.x, CHUNK_SIZE),
			posmod(pos.y, CHUNK_SIZE),
			posmod(pos.z, CHUNK_SIZE)
		)
		return neighbor_chunks[neighbor_pos].get_block(local_pos.x, local_pos.y, local_pos.z)

	return Block.BlockType.AIR

func _get_face_light(pos: Vector3i, neighbor_chunks: Dictionary) -> float:

	var light = float(_get_light_with_neighbors(pos, neighbor_chunks))
	return light

func _get_light_with_neighbors(pos: Vector3i, neighbor_chunks: Dictionary) -> int:
	if pos.x >= 0 and pos.x < CHUNK_SIZE and pos.y >= 0 and pos.y < CHUNK_SIZE and pos.z >= 0 and pos.z < CHUNK_SIZE:
		return chunk_data.get_light(pos.x, pos.y, pos.z)

	var chunk_offset = Vector3i(
		floori(float(pos.x) / CHUNK_SIZE),
		floori(float(pos.y) / CHUNK_SIZE),
		floori(float(pos.z) / CHUNK_SIZE)
	)
	var neighbor_pos = chunk_position + chunk_offset

	if neighbor_pos in neighbor_chunks:
		var local_pos = Vector3i(
			posmod(pos.x, CHUNK_SIZE),
			posmod(pos.y, CHUNK_SIZE),
			posmod(pos.z, CHUNK_SIZE)
		)
		return neighbor_chunks[neighbor_pos].get_light(local_pos.x, local_pos.y, local_pos.z)

	var clamped_pos = Vector3i(
		clampi(pos.x, 0, CHUNK_SIZE - 1),
		clampi(pos.y, 0, CHUNK_SIZE - 1),
		clampi(pos.z, 0, CHUNK_SIZE - 1)
	)
	return chunk_data.get_light(clamped_pos.x, clamped_pos.y, clamped_pos.z)

func _get_block_uv(block_type: int, face: String) -> Vector2i:
	var tex_data = Block.BLOCK_TEXTURES.get(block_type, Vector2i(0, 0))

	if tex_data is Dictionary:
		return tex_data.get(face, tex_data.get("side", Vector2i(0, 0)))
	else:
		return tex_data

func _is_completely_occluded(neighbor_chunks: Dictionary) -> bool:

	var directions = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]

	for direction in directions:
		var neighbor_pos = chunk_position + direction

		if neighbor_pos not in neighbor_chunks:
			return false

		var neighbor_data = neighbor_chunks[neighbor_pos]
		if not _is_neighbor_face_solid(neighbor_data, direction):
			return false

	return true

func _is_neighbor_face_solid(neighbor_data: ChunkData, direction: Vector3i) -> bool:

	var check_x = 0 if direction.x > 0 else (CHUNK_SIZE - 1) if direction.x < 0 else -1
	var check_y = 0 if direction.y > 0 else (CHUNK_SIZE - 1) if direction.y < 0 else -1
	var check_z = 0 if direction.z > 0 else (CHUNK_SIZE - 1) if direction.z < 0 else -1

	if check_x >= 0:  
		for y in CHUNK_SIZE:
			for z in CHUNK_SIZE:
				if Block.is_transparent(neighbor_data.get_block(check_x, y, z)):
					return false
	elif check_y >= 0:  
		for x in CHUNK_SIZE:
			for z in CHUNK_SIZE:
				if Block.is_transparent(neighbor_data.get_block(x, check_y, z)):
					return false
	elif check_z >= 0:  
		for x in CHUNK_SIZE:
			for y in CHUNK_SIZE:
				if Block.is_transparent(neighbor_data.get_block(x, y, check_z)):
					return false

	return true
