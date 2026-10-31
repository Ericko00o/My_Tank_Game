extends Control
const Sim = preload("res://scripts/simulation.gd")
var state: Dictionary = {}
var local_id := 1
var camera_center := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

static func is_player_visible(player: Dictionary, viewer: Dictionary) -> bool:
    if float(player.get("dead", 0.0)) > 0.0:
        return false
    return viewer.is_empty() or player.team == viewer.team or float(player.get("invisible", 0.0)) <= 0.0

func _draw() -> void:
    if state.is_empty():
        return
    var bounds := Rect2(Vector2.ZERO, size)
    draw_rect(bounds, Color(0.025, 0.07, 0.11, .88))
    draw_rect(bounds, Color("8ac7db"), false, 2.0)
    var scale_xy := size / Sim.WORLD
    var map_id := str(state.get("map_id", "ice"))
    for wall: Rect2 in Sim.wall_rects(map_id):
        draw_rect(Rect2(wall.position * scale_xy, wall.size * scale_xy), Color("91aeb6"))
    for obstacle in state.get("obstacles", []):
        if obstacle.hits > 0:
            draw_rect(Rect2(obstacle.rect.position * scale_xy, obstacle.rect.size * scale_xy), Color("b8f7ff"))
    var view_size := Vector2(1280, 720) * scale_xy
    draw_rect(Rect2(camera_center * scale_xy - view_size / 2.0, view_size), Color(1, 1, 1, .35), false, 1.0)
    for id in state.get("players", {}):
        var p: Dictionary = state.players[id]
        var own: Dictionary = state.players.get(local_id, {})
        if not is_player_visible(p, own):
            continue
        var color := Color("fff7a5") if id == local_id else (Color("58d8ff") if p.team == 0 else Color("ff6a5e"))
        draw_circle(p.position * scale_xy, 4.0 if id == local_id else 3.0, color)
