extends SceneTree
func _initialize() -> void:
    for path in ["res://assets/steel.png", "res://assets/wing.png"]:
        var im = Image.load_from_file(path)
        print(path, " size=", im.get_size(), " alpha=", im.get_pixel(0,0).a, " rect=", im.get_used_rect())
    quit()
