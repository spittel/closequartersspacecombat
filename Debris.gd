extends MeshInstance



var rings = 2
var radial_segments = 3
var height = 1
var radius = 1

var rng = RandomNumberGenerator.new()

func _ready():

	
	var sphere = create_sphere()

	var mdt = MeshDataTool.new()

	rng.randomize()
	var random_x = 0
	var random_y = 0
	var random_z = 0


	for n in 1000:
		mdt.create_from_surface(sphere, 0)
		
		var space_range = 800.0
		random_x = rng.randf_range(-space_range, space_range)
		random_y = rng.randf_range(-space_range, space_range)
		random_z = rng.randf_range(-space_range, space_range)
		
		for i in range(mdt.get_vertex_count()):
			var vert = mdt.get_vertex(i)
			vert /= 2

			vert.x += random_x
			vert.y += random_y
			vert.z += random_z
			
			mdt.set_vertex(i, vert)	
			
		mdt.commit_to_surface(sphere)
#		xplus +=10
	
	sphere.surface_remove(0) # Deletes the first surface of the mesh (the large prototype)
	
func create_sphere():
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)

	# PoolVectorXXArrays for mesh construction.
	var verts = PoolVector3Array()
	var uvs = PoolVector2Array()
	var normals = PoolVector3Array()
	var indices = PoolIntArray()

	#######################################
	## Creating a sphere ##
	#######################################
 # Vertex indices.
	var thisrow = 0
	var prevrow = 0
	var point = 0

	# Loop over rings.
	for i in range(rings + 1):
		var v = float(i) / rings
		var w = sin(PI * v)
		var y = cos(PI * v)

		# Loop over segments in ring.
		for j in range(radial_segments):
			var u = float(j) / radial_segments
			var x = sin(u * PI * 2.0)
			var z = cos(u * PI * 2.0)
			var vert = Vector3(x * radius * w, y, z * radius * w)
			verts.append(vert)
			normals.append(vert.normalized())
			uvs.append(Vector2(u, v))
			point += 1

			# Create triangles in ring using indices.
			if i > 0 and j > 0:
				indices.append(prevrow + j - 1)
				indices.append(prevrow + j)
				indices.append(thisrow + j - 1)

				indices.append(prevrow + j)
				indices.append(thisrow + j)
				indices.append(thisrow + j - 1)

		if i > 0:
			indices.append(prevrow + radial_segments - 1)
			indices.append(prevrow)
			indices.append(thisrow + radial_segments - 1)

			indices.append(prevrow)
			indices.append(prevrow + radial_segments)
			indices.append(thisrow + radial_segments - 1)

		prevrow = thisrow
		thisrow = point

	# Assign arrays to mesh array.
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices

	# Create mesh surface from mesh array.
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)	
	return mesh
