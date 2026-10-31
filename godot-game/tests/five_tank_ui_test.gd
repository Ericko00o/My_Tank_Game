extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func key(game: Node, code: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = true
    game._unhandled_input(event)
func run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    for i in range(5):
        game.tank_choice.select(i)
        game._start_practice()
        assert(game._local_player().tank == ["steel", "wing", "ghost", "dark", "elf"][i])
        var player: Dictionary = game.sim.players[1]
        assert(player.tank == ["steel", "wing", "ghost", "dark", "elf"][i])
        key(game, KEY_E)
        match player.tank:
            "steel": assert(player.boost > 0.0)
            "wing": assert(game.aim_mode == "missile")
            "ghost": assert(game.aim_mode == "ghost_hook")
            "dark": assert(player.invisible > 0.0)
            "elf": assert(game.aim_mode == "elf_arrow")
        game.aim_mode = ""
        key(game, KEY_SPACE)
        match player.tank:
            "steel", "wing": assert(game.aim_mode == "ultimate")
            "ghost": assert(player.ghost_channel > 0.0)
            "dark": assert(game.aim_mode == "dark_ult")
            "elf": assert(game.aim_mode == "elf_ult")
        game._return_to_menu()
    game.tank_choice.select(4)
    game._start_practice()
    game.sim.players[1].vine_root = 1.0
    game.view_state = game.sim.snapshot()
    key(game, KEY_E)
    assert(game.aim_mode == "")
    game.sim.players[-1].invisible = 3.0
    game.view_state = game.sim.snapshot()
    assert(game._is_hidden_enemy(game.view_state.players[-1]))
    game.sim.players[-1].team = 0
    game.view_state = game.sim.snapshot()
    assert(not game._is_hidden_enemy(game.view_state.players[-1]))
    game._return_to_menu()
    print("FIVE_TANK_UI_TEST_OK")
    quit()
