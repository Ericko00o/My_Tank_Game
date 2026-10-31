extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func fail(message: String) -> void:
    push_error(message)
    quit(1)
func run() -> void:
    var args := OS.get_cmdline_user_args()
    var role := args[0]
    var tank := args[1]
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    if role == "host":
        game._host_room()
        for i in range(100):
            if game.roster.size() == 2:
                break
            await create_timer(.05).timeout
        if game.roster.size() != 2 or game.roster[1].tank != tank:
            fail("host did not receive chosen tank")
            return
        game._start_match()
        var guest_id: int = int(game.roster[1].id)
        for i in range(120):
            var p: Dictionary = game.sim.players[guest_id]
            if (tank == "ghost" and p.ult_cd > 0.0) or (tank == "elf" and p.e_cd > 0.0) or (tank == "dark" and p.invisible > 0.0):
                print("NEW_NETWORK_HOST_OK ", tank)
                await create_timer(1.2).timeout
                quit(0)
                return
            await create_timer(.05).timeout
        fail("host did not process ability for " + tank)
    else:
        game.tank_choice.select({"ghost":2, "dark":3, "elf":4}[tank])
        game.ip_field.text = "127.0.0.1"
        game._join_room()
        for i in range(100):
            if game.in_match and game.view_state.has("players") and game.view_state.players.has(game.local_id):
                break
            await create_timer(.05).timeout
        if not game.in_match or not game.view_state.has("players") or not game.view_state.players.has(game.local_id):
            fail("client did not start")
            return
        var target: Vector2 = game.view_state.players[game.local_id].position + Vector2.LEFT * 100.0
        var action: String = {"ghost":"ghost_ult", "dark":"dark_stealth", "elf":"elf_arrow"}[tank]
        game._request_ability.rpc_id(1, action, target)
        for i in range(100):
            var p: Dictionary = game.view_state.players[game.local_id]
            if p.tank == tank and ((tank == "ghost" and p.ult_cd > 0.0) or (tank == "elf" and p.e_cd > 0.0) or (tank == "dark" and p.invisible > 0.0)):
                print("NEW_NETWORK_CLIENT_OK ", tank)
                quit(0)
                return
            await create_timer(.05).timeout
        fail("client did not receive ability state for " + tank)
