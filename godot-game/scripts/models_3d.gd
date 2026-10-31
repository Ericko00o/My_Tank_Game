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

static func make_view(parent: Node, kind: String) -> Dictionary:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(192, 160)
    viewport.transparent_bg = true
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
    var red := Color("b71f34")
    var dark := Color("242d39")
    var gold := Color("e0a83a")
    box(model, Vector3(2.3, .42, 1.38), Vector3(0, .35, 0), dark)
    for side in [-1, 1]:
        box(model, Vector3(2.8, .5, .54), Vector3(-.12, .27, side * .88), dark)
        box(model, Vector3(2.45, .25, .6), Vector3(-.12, .60, side * .88), red)
        cylinder(model, .26, .42, Vector3(1.12, .61, side * .88), red, Vector3(0, 0, PI / 2.0))
        for x in [-.9, -.45, 0.0, .45, .9]:
            box(model, Vector3(.12, .52, .57), Vector3(x, .29, side * .88), Color("64707b"))
    box(model, Vector3(1.9, .55, 1.4), Vector3(-.1, .75, 0), red)
    cylinder(model, .64, .34, Vector3(.05, 1.13, 0), gold)
    cylinder(model, .48, .35, Vector3(.05, 1.32, 0), red)
    box(model, Vector3(1.45, .3, .32), Vector3(1.06, 1.29, 0), dark)
    box(model, Vector3(.5, .38, .42), Vector3(1.8, 1.29, 0), gold)
    cylinder(model, .18, .04, Vector3(.05, 1.52, 0), Color("ffe47a"))

static func make_wing(model: Node3D) -> void:
    var blue := Color("1689cf")
    var navy := Color("193b64")
    var white := Color("e1f2f8")
    box(model, Vector3(2.1, .36, .85), Vector3(0, .42, 0), navy)
    box(model, Vector3(1.45, .42, .68), Vector3(.05, .78, 0), blue)
    box(model, Vector3(.8, .23, .45), Vector3(.0, 1.11, 0), white)
    for side in [-1, 1]:
        box(model, Vector3(1.45, .16, .95), Vector3(-.25, .38, side * .9), blue, Vector3(0, side * -.24, 0))
        for i in range(3):
            box(model, Vector3(1.22 - i * .13, .13, .34), Vector3(-.45 - i * .20, .45, side * (1.18 + i * .24)), white, Vector3(0, side * -.35, 0))
        box(model, Vector3(1.0, .30, .25), Vector3(-.72, .76, side * .56), navy)
    box(model, Vector3(1.7, .2, .25), Vector3(1.15, .72, 0), Color("bbcbd1"))
    box(model, Vector3(.35, .3, .35), Vector3(1.94, .72, 0), navy)
    cylinder(model, .22, .15, Vector3(.15, 1.28, 0), Color("82e8ff"))

static func make_block(model: Node3D, kind: String) -> void:
    var jungle := kind == "jungle"
    var breakable := kind == "breakable"
    var color := Color("93bfce") if breakable else (Color("849b76") if jungle else Color("a9d9e4"))
    box(model, Vector3(2.7, .9, 1.8), Vector3(0, .1, 0), color)
    box(model, Vector3(2.6, .10, 1.7), Vector3(0, .6, 0), Color("e0f9fa") if not jungle else Color("b9c8a0"))
    for x in [-.9, 0.0, .9]:
        box(model, Vector3(.08, .13, 1.5), Vector3(x, .67, 0), Color("b3e1e6") if not jungle else Color("759171"))
