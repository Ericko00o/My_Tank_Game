extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var errors := 0
func check(value: bool, message: String) -> void:
    if not value:
        errors += 1
        push_error(message)
func duel(attacker: String, defender: String = "steel"):
    var s = Sim.new()
    s.setup([{"id": 1, "tank": attacker, "team": 0}, {"id": 2, "tank": defender, "team": 1}], "ice")
    s.players[1].position = Vector2(100, 100)
    s.players[2].position = Vector2(280, 100)
    s.players[1].invulnerable = 0.0
    s.players[2].invulnerable = 0.0
    s.players[2].hp = 10000.0
    return s
func advance(s, count: int) -> void:
    for i in range(count):
        s.step(.05)
func arrow_damage(distance: float, marked: bool) -> float:
    var s = duel("elf")
    s.players[2].position = Vector2(100 + distance, 100)
    if marked:
        s.players[2].marks[1] = 3.0
    check(s.use_ability(1, "elf_arrow", s.players[2].position), "elf E must cast")
    advance(s, 30)
    return 10000.0 - s.players[2].hp
func _initialize() -> void:
    var s = duel("dark")
    check(s.players[1].max_hp == 1350.0 and s.players[1].tank == "dark", "dark roster")
    check(s.use_ability(1, "dark_stealth", Vector2.ZERO), "stealth starts")
    check(s.players[1].invisible == 5.0 and s.players[1].e_cd == 8.0, "stealth cooldown starts immediately")
    advance(s, 20)
    check(absf(s.players[1].invisible - 4.0) < .01 and absf(s.players[1].e_cd - 7.0) < .01, "stealth cooldown counts from press")
    s = duel("dark")
    s.players[2].max_hp = 1000.0
    check(s.use_ability(1, "dark_ult", s.players[2].position), "dark ultimate casts")
    check(s.players[2].hp == 9640.0 and s.players[2].poison_ultimate == 5.0, "dark ultimate initial hit and independent poison")
    s.players[1].aim = 0.0
    s.fire(s.players[1])
    advance(s, 104)
    check(absf(s.players[2].hp - 8320.0) < .1, "dark normal + ultimate poison totals: %s" % s.players[2].hp)
    s = duel("dark")
    s.players[2].max_hp = 1000.0
    s.players[2].hp = 230.0
    s.fire(s.players[1])
    advance(s, 40)
    check(s.players[2].dead > 0.0 and s.score[0] == 1, "poison kills and credits attacker")
    s = duel("dark")
    s.players[2].position = Vector2(400, 100)
    s.fire(s.players[1])
    s.fire(s.players[1])
    advance(s, 12)
    check(s.players[2].poison_normal > 3.7 and s.players[2].poison_normal <= 4.0, "normal poison stacks duration only")
    s = duel("dark")
    s.players[1].position = Vector2(100, 358)
    var obstacle_pos: Vector2 = s.obstacles[0].rect.get_center()
    check(s.use_ability(1, "dark_ult", obstacle_pos), "dark ultimate towards ice")
    check(s.obstacles[0].hits == 19, "dark ultimate counts once on ice")
    var near := arrow_damage(180, false)
    var far := arrow_damage(570, false)
    var marked := arrow_damage(180, true)
    check(near > 330 and far > near and absf(marked - near * 1.5) < .01, "elf arrow distance/mark damage %s %s %s" % [near, far, marked])
    s = duel("elf")
    s.players[1].position = Vector2(100, 358)
    s.players[2].position = Vector2(400, 358)
    check(s.use_ability(1, "elf_arrow", s.players[2].position), "elf E towards ice")
    advance(s, 20)
    check(s.obstacles[0].hits == 19 and s.players[2].hp == 10000.0, "elf E hits ice once and cannot pass")
    s = duel("elf")
    s.fire(s.players[1])
    advance(s, 12)
    check(s.players[2].marks.has(1), "elf normal shot applies mark")
    s = duel("elf", "ghost")
    check(s.use_ability(1, "elf_ult", s.players[2].position), "vine ultimate casts")
    advance(s, 8)
    check(s.players[2].vine_root > 1.8 and s.players[2].slow > 1.8, "vine root and slow")
    check(not s.use_ability(2, "ghost_hook", s.players[1].position), "vine root blocks skill")
    s.players[2].firing = true
    s.players[2].aim = PI
    var shots: int = s.players[2].shots
    advance(s, 2)
    check(s.players[2].shots > shots, "vine root still allows basic attack")
    s = duel("ghost")
    check(s.use_ability(1, "ghost_hook", s.players[2].position), "ghost hook casts")
    advance(s, 22)
    check(s.players[2].position.x < 170.0 and s.players[2].hp == 9900.0, "hook damages and pulls target near ghost")
    s = duel("ghost")
    s.players[2].position = Vector2(270, 100)
    s.players[1].firing = true
    s.set_input(1, Vector2.RIGHT, 0.0, true)
    check(s.use_ability(1, "ghost_ult", Vector2.ZERO), "ghost ultimate casts")
    advance(s, 5)
    check(s.players[1].position == Vector2(100, 100) and s.players[1].shots == 0, "ghost channels without movement or fire")
    s.players[2].position = Vector2(200, 100)
    s.players[2].firing = true
    s.set_input(2, Vector2.RIGHT, PI, true)
    advance(s, 3)
    check(s.players[2].ghost_root > 0.0 and s.players[2].hp < 10000.0, "new entrant rooted and burned")
    var rooted_pos: Vector2 = s.players[2].position
    var rooted_shots: int = s.players[2].shots
    advance(s, 4)
    check(s.players[2].position == rooted_pos and s.players[2].shots == rooted_shots, "ghost root blocks move and fire")
    s = duel("ghost")
    s.players[2].position = Vector2(200, 100)
    check(s.use_ability(1, "ghost_ult", Vector2.ZERO), "ghost full duration cast")
    advance(s, 42)
    check(absf(s.players[2].hp - 8400.0) < .01, "ghost ultimate deals 20 ticks of 80")
    s = duel("wing", "ghost")
    s.players[2].position = Vector2(200, 100)
    s.players[1].hp = 10000.0
    check(s.use_ability(1, "ultimate", Vector2(300, 100)), "wing begins charge")
    check(s.use_ability(2, "ghost_ult", Vector2.ZERO), "enemy casts ghost ultimate")
    advance(s, 30)
    check(s.players[1].charge == 0.0 and not s.effects.any(func(e): return e.kind == "laser"), "root interrupts charging skill")
    s = duel("steel", "ghost")
    s.players[2].position = Vector2(200, 100)
    s.players[2].hp = 1.0
    check(s.hit(2, 5.0, 1), "kill ghost")
    check(s.players[1].hp == Sim.STEEL_MAX - 75 and s.players[1].burns.size() == 1, "ghost passive explosion and burn")
    advance(s, 40)
    check(absf(s.players[1].hp - (Sim.STEEL_MAX - 75 - 140)) < .01, "ghost death burn ticks")
    s = duel("wing")
    s.players[1].position = Vector2(240, 180)
    s.players[1].aim = 0.0
    s.fire(s.players[1])
    check(s.bullets[0].position.x < 280.0, "muzzle does not pass through wall")
    advance(s, 2)
    check(s.bullets.is_empty(), "wall blocks muzzle projectile")
    s = duel("elf")
    s.players[2].position = Vector2(130, 100)
    s.fire(s.players[1])
    check(s.players[2].hp == 9865.0 and s.players[2].marks.has(1), "near target inside muzzle path receives basic attack")
    s = duel("wing")
    s.players[2].position = Vector2(135, 100)
    check(s.use_ability(1, "missile", s.players[2].position), "close-range missile target")
    advance(s, 12)
    check(s.players[2].hp == 9280.0, "all three missiles hit target within muzzle path")
    if errors == 0:
        print("NEW_TANKS_TEST_OK")
        quit(0)
    else:
        print("NEW_TANKS_TEST_ERRORS=", errors)
        quit(1)
