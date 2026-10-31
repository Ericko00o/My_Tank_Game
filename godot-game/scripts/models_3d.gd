extends RefCounted

static func material(color: Color, metallic: float = 0.15) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = 0.35
    return mat

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = material(color)
    node.position = pos
    node.rotation = rot
    parent.add_child(node)

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    node.mesh = mesh
    node.material_override = material(color, 0.45)
    node.position = pos
    node.rotation = rot
    parent.add_child(node)

static func ellipsoid(parent: Node3D, radius: Vector3, pos: Vector3, color: Color, metallic: float = 0.22) -> void:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 24
    mesh.rings = 12
    node.mesh = mesh
    node.scale = radius
    node.position = pos
    node.material_override = material(color, metallic)
    parent.add_child(node)

# A solid, beveled-looking plate with a custom silhouette in the X/Z plane.
static func plate(parent: Node3D, outline: PackedVector2Array, height: float, thickness: float, color: Color) -> void:
    var indices := Geometry2D.triangulate_polygon(outline)
    if indices.is_empty():
        return
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(0, indices.size(), 3):
        for j in [2, 1, 0]:
            var p: Vector2 = outline[indices[i + j]]
            surface.set_normal(Vector3.UP)
            surface.add_vertex(Vector3(p.x, height, p.y))
    for i in range(outline.size()):
        var a: Vector2 = outline[i]
        var b: Vector2 = outline[(i + 1) % outline.size()]
        var normal := Vector3(b.y - a.y, 0, a.x - b.x).normalized()
        var a0 := Vector3(a.x, height - thickness, a.y)
        var a1 := Vector3(a.x, height, a.y)
        var b0 := Vector3(b.x, height - thickness, b.y)
        var b1 := Vector3(b.x, height, b.y)
        for v in [a0, b0, b1, a0, b1, a1]:
            surface.set_normal(normal)
            surface.add_vertex(v)
    var node := MeshInstance3D.new()
    node.mesh = surface.commit()
    var mat := material(color, 0.25)
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    node.material_override = mat
    parent.add_child(node)

static func make_view(parent: Node, kind: String) -> Dictionary:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(192, 160)
    viewport.transparent_bg = true
    viewport.msaa_3d = Viewport.MSAA_4X
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.own_world_3d = true
    parent.add_child(viewport)
    var world := Node3D.new()
    viewport.add_child(world)
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0, 0, 0, 0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("d5ecff")
    environment.ambient_light_energy = 0.5
    env.environment = environment
    world.add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55, -35, 0)
    light.light_energy = 0.95
    world.add_child(light)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 4.8 if kind in ["steel", "wing"] else 4.2
    camera.position = Vector3(0, 7, 4.8)
    world.add_child(camera)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    camera.current = true
    var model := Node3D.new()
    world.add_child(model)
    if kind == "steel":
        make_steel(model)
    elif kind == "wing":
        make_wing(model)
    else:
        make_block(model, kind)
    return {"viewport": viewport, "model": model}

static func make_steel(model: Node3D) -> void:
    # Rounded crimson body, bright crown and paired mechanical outriggers,
    # following the silhouette in picter/鋼鐵.jpg.
    var red := Color("bf3047")
    var red_light := Color("e05566")
    var dark := Color("252c39")
    var metal := Color("74818c")
    var gold := Color("d7aa51")
    ellipsoid(model, Vector3(1.18, .36, .79), Vector3(-.06, .39, 0), dark)
    ellipsoid(model, Vector3(1.08, .50, .72), Vector3(-.16, .75, 0), red)
    ellipsoid(model, Vector3(.82, .19, .59), Vector3(-.25, 1.10, 0), red_light)
    ellipsoid(model, Vector3(.30, .16, .29), Vector3(-.49, 1.23, 0), metal)
    ellipsoid(model, Vector3(.21, .11, .20), Vector3(-.49, 1.35, 0), Color("dcefff"))
    cylinder(model, .37, .26, Vector3(.76, .68, 0), dark, Vector3(0, 0, PI / 2.0))
    cylinder(model, .30, .12, Vector3(.94, .68, 0), gold, Vector3(0, 0, PI / 2.0))
    ellipsoid(model, Vector3(.22, .24, .24), Vector3(1.03, .68, 0), Color("fa6388"))
    cylinder(model, .12, .42, Vector3(1.28, .68, 0), dark, Vector3(0, 0, PI / 2.0))
    cylinder(model, .15, .12, Vector3(1.50, .68, 0), metal, Vector3(0, 0, PI / 2.0))
    for side in [-1, 1]:
        var z: float = side * .78
        cylinder(model, .28, .34, Vector3(-.18, .56, z), metal, Vector3(PI / 2.0, 0, 0))
        cylinder(model, .23, .38, Vector3(.16, .52, z * 1.2), dark, Vector3(0, 0, PI / 2.0))
        ellipsoid(model, Vector3(.48, .29, .34), Vector3(.69, .43, z * 1.32), dark)
        ellipsoid(model, Vector3(.54, .25, .31), Vector3(.67, .63, z * 1.32), red)
        ellipsoid(model, Vector3(.35, .09, .24), Vector3(.72, .79, z * 1.32), red_light)
        cylinder(model, .23, .12, Vector3(.23, .55, z * 1.32), gold, Vector3(0, 0, PI / 2.0))
        box(model, Vector3(.15, .12, .52), Vector3(1.0, .38, z * 1.32), metal)
        box(model, Vector3(.15, .12, .52), Vector3(1.15, .38, z * 1.32), dark)
        ellipsoid(model, Vector3(.35, .28, .30), Vector3(-.48, .60, side * .67), red)
        cylinder(model, .12, .08, Vector3(-.88, .57, side * .48), gold, Vector3(0, 0, PI / 2.0))

static func make_wing(model: Node3D) -> void:
    # White feathered wings, cyan armor, gold crest, and a long twin barrel.
    var blue := Color("168fcd")
    var light_blue := Color("6dcff2")
    var navy := Color("243c59")
    var white := Color("dceef2")
    var steel := Color("9cabb4")
    var gold := Color("e6ba5e")
    plate(model, PackedVector2Array([Vector2(1.04, 0), Vector2(.34, -.54), Vector2(-.85, -.48), Vector2(-1.12, 0), Vector2(-.85, .48), Vector2(.34, .54)]), .54, .24, navy)
    ellipsoid(model, Vector3(.92, .35, .47), Vector3(-.18, .75, 0), blue)
    ellipsoid(model, Vector3(.61, .19, .35), Vector3(-.16, 1.00, 0), light_blue)
    plate(model, PackedVector2Array([Vector2(.48, 0), Vector2(-.15, -.35), Vector2(-.84, -.25), Vector2(-.58, 0), Vector2(-.84, .25), Vector2(-.15, .35)]), 1.11, .12, white)
    ellipsoid(model, Vector3(.30, .16, .25), Vector3(.03, 1.17, 0), blue)
    ellipsoid(model, Vector3(.15, .09, .15), Vector3(.12, 1.29, 0), Color("a9f3ff"))
    for side in [-1, 1]:
        plate(model, PackedVector2Array([Vector2(.38, side * .38), Vector2(-.12, side * 1.08), Vector2(-1.30, side * 1.90), Vector2(-.82, side * 1.13), Vector2(-.95, side * .53)]), .55, .13, blue)
        for i in range(4):
            var z0: float = side * (.71 + i * .22)
            var x0: float = -.16 - i * .14
            plate(model, PackedVector2Array([Vector2(x0 + .38, z0), Vector2(x0 + .06, z0 + side * .20), Vector2(x0 - .95, z0 + side * .54), Vector2(x0 - .52, z0 - side * .06)]), .67 + i * .018, .10, white if i % 2 == 0 else Color("adcbd6"))
        ellipsoid(model, Vector3(.50, .23, .27), Vector3(-.55, .83, side * .54), blue)
        ellipsoid(model, Vector3(.30, .11, .21), Vector3(-.57, 1.03, side * .54), light_blue)
        plate(model, PackedVector2Array([Vector2(-.20, side * .35), Vector2(-.48, side * .40), Vector2(-.72, side * .14), Vector2(-.58, side * .10)]), 1.30, .08, gold)
        cylinder(model, .13, .85, Vector3(1.09, .72, side * .14), steel, Vector3(0, 0, PI / 2.0))
        cylinder(model, .16, .18, Vector3(1.53, .72, side * .14), navy, Vector3(0, 0, PI / 2.0))
    box(model, Vector3(.75, .25, .54), Vector3(.56, .72, 0), navy)
    box(model, Vector3(.35, .12, .62), Vector3(.66, .91, 0), steel)

static func make_block(model: Node3D, kind: String) -> void:
    var jungle := kind == "jungle"
    var breakable := kind == "breakable"
    var color := Color("93bfce") if breakable else (Color("849b76") if jungle else Color("a9d9e4"))
    box(model, Vector3(2.7, .9, 1.8), Vector3(0, .1, 0), color)
    box(model, Vector3(2.6, .10, 1.7), Vector3(0, .6, 0), Color("e0f9fa") if not jungle else Color("b9c8a0"))
    for x in [-.9, 0.0, .9]:
        box(model, Vector3(.08, .13, 1.5), Vector3(x, .67, 0), Color("b3e1e6") if not jungle else Color("759171"))
