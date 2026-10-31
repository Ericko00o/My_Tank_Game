extends SceneTree
const Sim = preload("res://scripts/simulation.gd")

func _initialize() -> void:
    var s = Sim.new()
    var roster := [{"id":1,"name":"鋼鐵","tank":"steel","team":0},{"id":2,"name":"飛翼","tank":"wing","team":1}]
    for map_id in ["ice","jungle"]:
        s.setup(roster, map_id)
        for player in s.players.values():
            if s.blocked(player.position):
                _fail("spawn is blocked: " + map_id)
        if not s.blocked(Sim.MAPS[map_id][0].get_center()):
            _fail("wall collision missing: " + map_id)
    s.setup(roster, "ice")
    var steel: Dictionary = s.players[1]
    var wing: Dictionary = s.players[2]
    steel.position = Vector2(100, 100)
    wing.position = Vector2(200, 100)
    wing.hp = 10000.0
    wing.max_hp = 10000.0
    wing.invulnerable = 0.0
    var start: Vector2 = steel.position
    s.set_input(1, Vector2.RIGHT, 0.0, false)
    s.step(.05)
    if steel.position.x <= start.x:
        _fail("movement failed")
    steel.position = Vector2(100, 100)
    s.set_input(1, Vector2.ZERO, 0.0, false)
    for i in range(7):
        s.fire(steel)
    if s.bullets.size() != 7 or not s.bullets[6].pierce or s.bullets[6].damage != 258.0:
        _fail("steel seventh shot failed")
    s.bullets.clear()
    if not s.use_ability(1, "ultimate", Vector2(200, 100)):
        _fail("steel ultimate rejected")
    for i in range(64):
        s.step(.05)
    if not is_equal_approx(10000.0 - wing.hp, Sim.STEEL_MAX * 0.5):
        _fail("steel ultimate damage: %s" % (10000.0 - wing.hp))
    s.setup(roster, "ice")
    steel = s.players[1]
    wing = s.players[2]
    wing.position = Vector2(100, 100)
    steel.position = Vector2(300, 100)
    steel.hp = 10000.0
    steel.max_hp = 10000.0
    steel.invulnerable = 0.0
    if not s.use_ability(2, "ultimate", Vector2(500, 100)):
        _fail("wing ultimate rejected")
    s.set_input(2, Vector2.RIGHT, PI, false)
    for i in range(19):
        s.step(.05)
    if steel.hp != 10000.0 or wing.position != Vector2(100,100):
        _fail("wing charge timing or lock")
    for i in range(2):
        s.step(.05)
    if steel.hp != 8800.0:
        _fail("wing damage: %s" % steel.hp)
    s.setup(roster, "ice")
    steel = s.players[1]
    wing = s.players[2]
    steel.position = Vector2(100, 100)
    wing.position = Vector2(250, 100)
    steel.invulnerable = 0.0
    if not s.use_ability(2, "missile", steel.position):
        _fail("missile target rejected")
    for i in range(40):
        s.step(.05)
    if steel.hp >= steel.max_hp:
        _fail("missiles failed to hit")
    print("SIMULATION_TEST_OK")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
