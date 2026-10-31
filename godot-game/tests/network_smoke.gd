extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var role := args[0] if not args.is_empty() else ""
    var scene: PackedScene = load("res://main.tscn")
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    if role == "host":
        game.name_field.text = "Host"
        game._host_room()
        if not game.networked:
            _fail("failed to host: " + game.notice.text)
            return
        for i in range(100):
            if game.roster.size() == 2:
                break
            await create_timer(.1).timeout
        if game.roster.size() != 2:
            _fail("client did not join")
            return
        game._start_match()
        var other_id: int = int(game.roster[1].id)
        var original_x: float = game.sim.players[other_id].position.x
        for i in range(100):
            if game.sim.players.has(other_id) and game.sim.players[other_id].position.x < original_x - 4.0 and game.sim.players[other_id].e_cd > 0.0 and is_equal_approx(absf(game.sim.players[other_id].hull_angle), PI) and is_zero_approx(game.sim.players[other_id].aim):
                print("NETWORK_HOST_OK")
                await create_timer(2.0).timeout
                quit(0)
                return
            await create_timer(.1).timeout
        _fail("host did not receive movement and ability")
    elif role == "client":
        game.name_field.text = "Client"
        game.ip_field.text = "127.0.0.1"
        game._join_room()
        for i in range(100):
            if game.in_match and not game.view_state.is_empty():
                break
            await create_timer(.1).timeout
        if not game.in_match or game.view_state.is_empty():
            _fail("client did not receive match")
            return
        game._request_ability.rpc_id(1, "boost", Vector2.ZERO)
        # Drive inputs explicitly so movement and aim deliberately differ.
        game.set_process(false)
        for i in range(20):
            game._receive_input.rpc_id(1, Vector2.LEFT, 0.0, false)
            await create_timer(.05).timeout
        if game.view_state.players.size() != 2:
            _fail("snapshot roster missing")
            return
        var own: Dictionary = game.view_state.players[game.local_id]
        if not is_equal_approx(absf(own.hull_angle), PI) or not is_zero_approx(own.aim):
            _fail("independent hull/aim headings not synchronized")
            return
        print("NETWORK_CLIENT_OK")
        quit(0)
    else:
        _fail("missing role")

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
