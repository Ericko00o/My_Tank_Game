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
            _fail("failed to host")
            return
        for i in range(150):
            if game.roster.size() == 4:
                break
            await create_timer(.1).timeout
        if game.roster.size() != 4:
            _fail("expected 4 players, got %s" % game.roster.size())
            return
        game._start_match()
        for i in range(100):
            var ready := true
            for entry in game.roster:
                if entry.id == 1:
                    continue
                if not game.sim.players.has(entry.id):
                    ready = false
                    break
                var p: Dictionary = game.sim.players[entry.id]
                if p.position.y >= 245.0 and p.spawn_index == 0:
                    ready = false
                if p.position.y >= 465.0 and p.spawn_index == 1:
                    ready = false
                if p.e_cd <= 0.0:
                    ready = false
            if ready:
                print("FOUR_PLAYER_HOST_OK")
                await create_timer(1.5).timeout
                game._close_network()
                quit(0)
                return
            await create_timer(.1).timeout
        _fail("host did not receive all player inputs")
    elif role == "client":
        game.name_field.text = "Client"
        game.ip_field.text = "127.0.0.1"
        game._join_room()
        for i in range(150):
            if game.in_match and not game.view_state.is_empty():
                break
            await create_timer(.1).timeout
        if not game.in_match or game.view_state.is_empty():
            _fail("client did not receive match")
            return
        game._send_ability("boost", Vector2.ZERO)
        var press := InputEventKey.new()
        press.keycode = KEY_W
        press.pressed = true
        Input.parse_input_event(press)
        await process_frame
        var original: Vector2 = game.visual_positions[game.local_id]
        game._predict_client(.05)
        if game.visual_positions[game.local_id].y >= original.y:
            _fail("local input prediction did not move")
            return
        for i in range(20):
            await create_timer(.05).timeout
        var release := InputEventKey.new()
        release.keycode = KEY_W
        release.pressed = false
        Input.parse_input_event(release)
        if game.view_state.get("players", {}).size() != 4:
            _fail("snapshot did not contain four players")
            return
        print("FOUR_PLAYER_CLIENT_OK")
        await create_timer(2.0).timeout
        quit(0)
    else:
        _fail("missing role")

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
