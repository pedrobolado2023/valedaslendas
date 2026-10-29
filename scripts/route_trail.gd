class_name RouteTrail
extends MultiMeshInstance3D
## Setas brilhantes no chão mostrando o caminho até a missão.

const SPACING := 2.4
const MAX := 220


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# divisa ">" apontando para -Z, deitada no chão
	var pts := [Vector3(-0.55, 0, 0.3), Vector3(0, 0, -0.35), Vector3(0.55, 0, 0.3), Vector3(0.55, 0, 0.62), Vector3(0, 0, 0.0), Vector3(-0.55, 0, 0.62)]
	var tris := [0, 1, 4, 0, 4, 5, 1, 2, 3, 1, 3, 4]
	for i in tris:
		st.set_normal(Vector3.UP)
		st.add_vertex(pts[i])
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/trail.gdshader")
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func show_route(points: PackedVector3Array) -> void:
	var mm := multimesh
	var n := 0
	var carry := 1.5
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := Vector3(b.x - a.x, 0, b.z - a.z)
		var L := seg.length()
		if L < 0.01:
			continue
		var d := seg / L
		var basis := Basis(Vector3.UP, atan2(-d.x, -d.z))
		var t := carry
		while t < L and n < MAX:
			var p := a + d * t
			mm.set_instance_transform(n, Transform3D(basis, Vector3(p.x, 0.12, p.z)))
			mm.set_instance_custom_data(n, Color(float(n), 0, 0, 0))
			n += 1
			t += SPACING
		carry = t - L
	mm.visible_instance_count = n


func clear() -> void:
	multimesh.visible_instance_count = 0
