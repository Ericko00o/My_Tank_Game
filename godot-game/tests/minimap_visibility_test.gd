extends SceneTree
const Map = preload("res://scripts/minimap.gd")
func _initialize() -> void:
    var viewer := {"team": 0}
    assert(not Map.is_player_visible({"team": 1, "invisible": 3.0}, viewer))
    assert(Map.is_player_visible({"team": 0, "invisible": 3.0}, viewer))
    assert(Map.is_player_visible({"team": 1, "invisible": 0.0}, viewer))
    assert(not Map.is_player_visible({"team": 0, "dead": 2.0}, viewer))
    print("MINIMAP_VISIBILITY_TEST_OK")
    quit(0)
