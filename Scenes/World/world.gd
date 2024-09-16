extends Node3D

var noise = FastNoiseLite.new()
var chunks: Dictionary = {}
var height_map: Dictionary = {}
var chunk_size = Vector3(64, 8, 64)
var unload_distance := 2
var load_distance := 2

@export var chunkScene := preload("res://Scenes/World/basic_chunk.tscn")
@onready var player := get_tree().get_first_node_in_group("player")

func _ready():
	setup_noise()

func _process(_delta):
	generate_player_chunks()
	unload_distant_chunks()
	_complete_dig()

func setup_noise():
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func generate_surrounding_chunks():
	for x in range(-1, 2):
		for z in range(-1, 2):
			generate_chunk(Vector3(x, 0, z) * chunk_size)

func generate_player_chunks():
	var player_chunk = (player.global_transform.origin / chunk_size).floor()
	for x in range(int(player_chunk.x) - load_distance + 1, int(player_chunk.x) + load_distance):
		for z in range(int(player_chunk.z) - load_distance + 1, int(player_chunk.z) + load_distance):
			var chunk_pos = Vector3(x, 0, z) * chunk_size
			if not chunks.has(chunk_pos):
				generate_chunk(chunk_pos)

func unload_distant_chunks():
	var player_chunk = (player.global_transform.origin / chunk_size).floor()
	var chunks_to_remove = []
	for chunk_pos in chunks.keys():
		var chunk_distance = chunk_pos.distance_to(player_chunk * chunk_size)
		if chunk_distance > unload_distance * chunk_size.x:
			chunks_to_remove.append(chunk_pos)
	for chunk_pos in chunks_to_remove:
		var chunk = chunks[chunk_pos]
		chunk.queue_free()
		chunks.erase(chunk_pos)

func generate_chunk(chunk_pos: Vector3):
	if chunks.has(chunk_pos):
		chunks[chunk_pos].queue_free()
		chunks.erase(chunk_pos)
	if not height_map.has(chunk_pos):
		height_map[chunk_pos] = generate_heights(chunk_pos)
	var heights = height_map[chunk_pos]
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points = generate_points(heights, chunk_pos)
	for point in points:
		surface_tool.add_vertex(point)
	surface_tool.generate_normals()
	var newmesh = ArrayMesh.new()
	newmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_tool.commit_to_arrays())
	var chunk = chunkScene.instantiate()
	chunk.mesh = newmesh
	self.add_child(chunk)
	chunks[chunk_pos] = chunk
	var static_body = StaticBody3D.new()
	chunk.add_child(static_body)
	var collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(surface_tool.commit_to_arrays()[Mesh.ARRAY_VERTEX])
	collision_shape.shape = shape

func generate_heights(chunk_pos: Vector3) -> Array:
	var heights = []
	for z in range(chunk_size.z + 1):
		var row = []
		for x in range(chunk_size.x + 1):
			var world_x = x + chunk_pos.x
			var world_z = z + chunk_pos.z
			var height = noise.get_noise_2d(world_x, world_z) * chunk_size.y
			if height < 0:
				height = 0
			row.append(height)
		heights.append(row)
	return heights

func generate_points(heights: Array, chunk_pos: Vector3) -> Array:
	var points = []
	for z in range(chunk_size.z):
		for x in range(chunk_size.x):
			points.append(Vector3(x,     heights[z][x],     z)     + chunk_pos)
			points.append(Vector3(x + 1, heights[z][x + 1], z)     + chunk_pos)
			points.append(Vector3(x,     heights[z + 1][x], z + 1) + chunk_pos)
			points.append(Vector3(x + 1, heights[z][x + 1], z)     + chunk_pos)
			points.append(Vector3(x + 1, heights[z + 1][x + 1], z + 1) + chunk_pos)
			points.append(Vector3(x,     heights[z + 1][x], z + 1) + chunk_pos)
	return points

# dig_request_amount: the amount to dig, can be summed across multiple physics frames called in dig()
# and then processed in _complete_dig()
var dig_request_amount := 0.0
var dig_target_position: Vector3
# Whether last action was digging (true) or placing dirt (false)
var is_digging: bool

func dig(dig_position: Vector3, amount: float, isDigging: bool = true):
	dig_target_position = dig_position
	dig_request_amount += amount
	is_digging = isDigging

func _complete_dig():
	if dig_request_amount > 0:
		var chunk_pos = (dig_target_position / chunk_size).floor() * chunk_size
		chunk_pos.y = 0 # ensures chunk is always found no matter height
		if height_map.has(chunk_pos):
			var heights = height_map[chunk_pos]
			var local_pos = (dig_target_position - chunk_pos)
			var x = int(local_pos.x)
			var z = int(local_pos.z)
			var y = int(local_pos.y)
			var dig_amount = dig_request_amount / 15.0
			if is_digging: dig_amount *= -1
			_dig_height_calculation(heights, z, x , dig_amount, chunk_pos)
			generate_chunk(chunk_pos)  # Regenerate the chunk to show the changes.
		dig_request_amount = 0

				
## calculates height change with a weighted bias towards center
func _dig_height_calculation(heights: Array, z: int, x: int, digAmount: float, chunk_pos: Vector3) -> void:
	chunks_to_regenerate.clear()
	# Modify the height at the center and neighboring points
	_dig_at_point(heights, z, x, digAmount, chunk_pos)
	_dig_at_point(heights, z, x + 1, digAmount, chunk_pos)
	_dig_at_point(heights, z - 1, x, digAmount, chunk_pos)
	_dig_at_point(heights, z + 1, x, digAmount, chunk_pos)
	_dig_at_point(heights, z, x - 1, digAmount, chunk_pos)
	_dig_at_point(heights, z + 1, x + 1, digAmount, chunk_pos)
	_dig_at_point(heights, z - 1, x - 1, digAmount, chunk_pos)
	_dig_at_point(heights, z + 1, x - 1, digAmount, chunk_pos)
	_dig_at_point(heights, z - 1, x + 1, digAmount, chunk_pos)
	# Regenerate the modified chunks
	for chunk_posi in chunks_to_regenerate:
		generate_chunk(chunk_posi)
	
var chunks_to_regenerate: Array = []
func _dig_at_point(heights: Array, z: int, x: int, digAmount: float, chunk_pos: Vector3) -> void:
	var target_height: float = heights[z][x] + digAmount * 3
	heights[z][x] = target_height
	# Handle neighboring chunks on the Z-axis
	if z < 1:
		var chunk_south = chunk_pos - Vector3(0, 0, chunk_size.z)
		_modify_neighbor_chunk(chunk_south, clamp(chunk_size.z + z, 0, chunk_size.z), x, target_height)
	elif z > chunk_size.z - 1:
		var chunk_north = chunk_pos + Vector3(0, 0, chunk_size.z)
		_modify_neighbor_chunk(chunk_north, clamp(z - chunk_size.z, 0, chunk_size.z), x, target_height)
	# Handle neighboring chunks on the X-axis
	if x < 1:
		var chunk_west = chunk_pos - Vector3(chunk_size.x, 0, 0)
		_modify_neighbor_chunk(chunk_west, z, clamp(chunk_size.x + x, 0, chunk_size.x), target_height)
	elif x > chunk_size.x - 1:
		var chunk_east = chunk_pos + Vector3(chunk_size.x, 0, 0)
		_modify_neighbor_chunk(chunk_east, z, clamp(x - chunk_size.x, 0, chunk_size.x), target_height)

func _modify_neighbor_chunk(chunk_pos: Vector3, z: int, x: int, target_height: float) -> void:
	if not height_map.has(chunk_pos):
		height_map[chunk_pos] = generate_heights(chunk_pos)  # Generate chunk heights if missing
	var near_heights = height_map[chunk_pos]
	near_heights[z][x] = target_height
	# Mark the chunk for regeneration if not already scheduled
	if not chunks_to_regenerate.has(chunk_pos):
		chunks_to_regenerate.append(chunk_pos)
