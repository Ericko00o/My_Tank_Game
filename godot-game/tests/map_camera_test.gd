extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    game._start_practice()
    await process_frame
    game.set_process(false)
    assert(Sim.WORLD == Vector2(2560, 1440))
    assert(game.sim.walls.size() == Sim.MAPS.ice.size() * 4)
    assert(game.sim.obstacles.size() == Sim.BREAKABLE_MAPS.ice.size() * 4)
    game.sim.players[1].position = Vector2(1400, 900)
    game.view_state = game.sim.snapshot()
    game._update_camera_and_models()
    assert(game.camera.position == Vector2(1400, 900))
    assert(game.minimap.camera_center == game.camera.position)
    assert(game.minimap.state.players[1].position == Vector2(1400, 900))
    assert(game.tank_models.size() == 2)
    assert(game.tank_models[1].hull.get_child_count() > 0)
    assert(game.tank_models[1].turret.get_child_count() > 0)
    game.sim.players[1].hull_angle = PI / 2.0
    game.sim.players[1].aim = -PI / 4.0
    game.view_state = game.sim.snapshot()
    game._update_camera_and_models()
    assert(is_equal_approx(game.tank_models[1].hull.rotation.y, -PI / 2.0))
    assert(is_equal_approx(game.tank_models[1].turret.rotation.y, PI / 4.0))
    # A guest predicts its own hull but must retain the host's locked charge aim.
    game.is_host = false
    game.predicted_hull_ready = true
    game.predicted_hull_angle = 0.4
    game.view_state.players[1].charge = .5
    game.view_state.players[1].aim = 1.2
    game._update_camera_and_models()
    assert(is_equal_approx(game.tank_models[1].hull.rotation.y, -0.4))
    assert(is_equal_approx(game.tank_models[1].turret.rotation.y, -1.2))
    game.is_host = true
    assert(game.block_models.ice.model.get_child_count() > 0)
    game.sim.players[1].position = Vector2(30, 30)
    game.view_state = game.sim.snapshot()
    game._update_camera_and_models()
    assert(game.camera.position == Vector2(640, 360))
    game._return_to_menu()
    assert(not game.camera.enabled and not game.minimap.visible)
    print("MAP_CAMERA_3D_TEST_OK")
    quit()
