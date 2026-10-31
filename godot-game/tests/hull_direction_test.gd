extends SceneTree

const Sim = preload("res://scripts/simulation.gd")

func _initialize() -> void:
    var sim = Sim.new()
    sim.setup([{"id": 1, "tank": "wing", "team": 0}, {"id": 2, "tank": "steel", "team": 1}], "ice")
    var player: Dictionary = sim.players[1]
    player.position = Vector2(100, 100)
    if not _expect(is_equal_approx(player.hull_angle, 0.0), "initial hull heading"):
        return
    sim.set_input(1, Vector2.DOWN, 0.0, false)
    sim.step(0.05)
    if not _expect(is_equal_approx(player.hull_angle, PI / 2.0) and is_equal_approx(player.aim, 0.0), "movement and aim are independent"):
        return
    var snapshot: Dictionary = bytes_to_var(var_to_bytes(sim.snapshot()))
    if not _expect(is_equal_approx(snapshot.players[1].hull_angle, PI / 2.0), "snapshot preserves the hull heading"):
        return
    sim.set_input(1, Vector2.ZERO, PI, false)
    sim.step(0.05)
    if not _expect(is_equal_approx(player.hull_angle, PI / 2.0) and is_equal_approx(absf(player.aim), PI), "idle hull stays fixed when aiming"):
        return
    sim.set_input(1, Vector2(-1, -1), -0.4, false)
    sim.step(0.05)
    if not _expect(is_equal_approx(player.hull_angle, -3.0 * PI / 4.0), "diagonal movement sets heading"):
        return
    var old_heading: float = player.hull_angle
    var position: Vector2 = player.position
    if not _expect(sim.use_ability(1, "ultimate", position + Vector2.RIGHT * 100.0), "charge starts"):
        return
    sim.set_input(1, Vector2.RIGHT, PI / 2.0, false)
    sim.step(0.05)
    if not _expect(is_equal_approx(player.hull_angle, old_heading) and player.position == position and is_equal_approx(player.aim, 0.0), "charging locks orientation and movement"):
        return
    player.charge = 0.0
    player.dead = 1.0
    sim.set_input(1, Vector2.LEFT, 0.0, false)
    sim.step(0.05)
    if not _expect(is_equal_approx(player.hull_angle, old_heading), "dead hull keeps previous heading"):
        return
    print("HULL_DIRECTION_TEST_OK")
    quit(0)

func _expect(value: bool, message: String) -> bool:
    if not value:
        push_error(message)
        quit(1)
    return value
