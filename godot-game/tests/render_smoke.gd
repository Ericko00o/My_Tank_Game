extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("user://menu-preview.png")
    game._start_practice()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("user://match-preview.png")
    game.map_choice.select(1)
    game._start_practice()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("user://jungle-preview.png")
    print("RENDER_TEST_OK")
    quit(0)
