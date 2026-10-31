extends SceneTree
const Sim = preload("res://scripts/simulation.gd")

func _initialize() -> void:
    var s = Sim.new()
    s.setup([{"id": 1, "tank": "wing", "team": 0}, {"id": -1, "tank": "steel", "team": 1}], "ice")
    var wing: Dictionary = s.players[1]
    var enemy: Dictionary = s.players[-1]
    wing.position = Vector2(100, 100)
    enemy.position = Vector2(200, 100)
    enemy.invulnerable = 0.0
    assert(s.use_ability(1, "missile", enemy.position), "practice target must be valid")
    for i in range(40):
        s.step(0.05)
    assert(enemy.hp < enemy.max_hp, "missile must hit practice target")
    s.setup([{"id": 1, "tank": "wing", "team": 0}], "ice")
    wing = s.players[1]
    wing.position = Vector2(100, 358)
    var center: Vector2 = s.obstacles[0].rect.get_center()
    assert(s.use_ability(1, "missile", center), "obstacles can be missile targets")
    for i in range(40):
        s.step(0.05)
    assert(s.obstacles[0].hits == 17, "three missiles count separately")
    wing.charge_angle = 0.0
    s.fire_laser(wing)
    assert(s.obstacles[0].hits == 16, "laser counts once")
    for i in range(15):
        s.damage_obstacle(0)
    assert(s.blocked(center, 2.0), "obstacle survives 19 hits")
    s.damage_obstacle(0)
    assert(not s.blocked(center, 2.0), "obstacle disappears on hit 20")
    assert(s.snapshot().obstacles[0].hits == 0, "destroyed state included in snapshots")
    s.setup([{"id": 1, "tank": "steel", "team": 0}], "ice")
    var steel: Dictionary = s.players[1]
    steel.position = Vector2(100, 358)
    steel.aim = 0.0
    steel.shots = 6
    s.fire(steel)
    for i in range(20):
        s.step(0.05)
    assert(s.obstacles[0].hits == 19, "piercing projectile counts only once")
    assert(s.use_ability(1, "ultimate", s.obstacles[0].rect.get_center()), "bombard activated")
    for i in range(65):
        s.step(0.05)
    assert(s.obstacles[0].hits == 19, "damage over time must not count")
    print("BREAKABLE_TEST_OK")
    quit(0)
