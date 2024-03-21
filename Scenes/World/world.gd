extends Node3D

var noise = FastNoiseLite.new()
var chunks: Dictionary = {}
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

func setup_noise():
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
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
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var heights = generate_heights(chunk_pos)
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
			row.append(noise.get_noise_2d(world_x, world_z) * chunk_size.y)
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
