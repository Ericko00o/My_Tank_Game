class_name ArenaSimulation
extends RefCounted

const WORLD := Vector2(2560, 1440)
const TILE_SIZE := Vector2(1280, 720)
const STEEL_MAX := 1227.0
const WING_MAX := 1296.0
const MUZZLE_OFFSET := 42.0
const GHOST_RANGE := 576.0
const GHOST_HOOK_RANGE := 500.0
const GHOST_RADIUS := 125.0
const ELF_SHOT_RANGE := 1302.0
const ELF_ARROW_RANGE := 800.0
const ELF_ULT_RANGE := 850.0
const VINE_RADIUS := 80.0
const DARK_SHOT_RANGE := (576.0 * 2.0 / 3.0)
const DARK_ULT_RANGE := 299.0
const DARK_ULT_HALF_ANGLE := 0.55
const BEAM_RANGE := 406.25 * 4.0 / 3.0 * 1.4
const CAST_RANGE := 430.0
const MAPS := {
    "ice": [Rect2(280, 150, 130, 65), Rect2(870, 150, 130, 65), Rect2(480, 290, 95, 115), Rect2(705, 290, 95, 115), Rect2(280, 505, 130, 65), Rect2(870, 505, 130, 65)],
    "jungle": [Rect2(280, 110, 115, 100), Rect2(885, 110, 115, 100), Rect2(350, 300, 120, 75), Rect2(810, 300, 120, 75), Rect2(585, 260, 110, 90), Rect2(280, 510, 115, 100), Rect2(885, 510, 115, 100)]
}

const BREAKABLE_MAPS := {
    "ice": [Rect2(195, 330, 56, 56), Rect2(1029, 330, 56, 56), Rect2(612, 120, 56, 56), Rect2(612, 544, 56, 56)],
    "jungle": [Rect2(195, 330, 56, 56), Rect2(1029, 330, 56, 56), Rect2(525, 480, 56, 56), Rect2(699, 180, 56, 56)]
}
const OBSTACLE_HITS := 20
var obstacles: Array = []
var walls: Array = []
var players: Dictionary = {}
var bullets: Array = []
var effects: Array = []
var fields: Array = []
var map_id := "ice"
var time_left := 180.0
var score := [0, 0]
var running := false
var round_over := false
var id_counter := 0

func setup(roster: Array, chosen_map: String) -> void:
    players.clear()
    obstacles.clear()
    bullets.clear()
    effects.clear()
    fields.clear()
    map_id = chosen_map if MAPS.has(chosen_map) else "ice"
    walls = wall_rects(map_id)
    for y in range(2):
        for x in range(2):
            for rect: Rect2 in BREAKABLE_MAPS[map_id]:
                obstacles.append({"rect": Rect2(rect.position + Vector2(x * TILE_SIZE.x, y * TILE_SIZE.y), rect.size), "hits": OBSTACLE_HITS})
    time_left = 180.0
    score = [0, 0]
    running = true
    round_over = false
    id_counter = 0
    var team_counts := [0, 0]
    for entry in roster:
        var team: int = int(entry.get("team", 0))
        team = clampi(team, 0, 1)
        var index: int = team_counts[team]
        team_counts[team] += 1
        var tank: String = str(entry.get("tank", "steel"))
        if tank not in ["steel", "wing", "ghost", "elf", "dark"]:
            tank = "steel"
        var peer_id: int = int(entry.get("id", 1))
        var max_hp: float = {"steel": STEEL_MAX, "wing": WING_MAX, "ghost": 1350.0, "elf": 1100.0, "dark": 1350.0}[tank]
        players[peer_id] = {
            "id": peer_id, "name": str(entry.get("name", "Player")).substr(0, 14),
            "team": team, "tank": tank, "position": spawn_position(team, index),
            "spawn_index": index, "hp": max_hp, "max_hp": max_hp,
            "direction": Vector2.ZERO, "aim": 0.0, "hull_angle": 0.0, "firing": false, "fire_cd": 0.0,
            "e_cd": 0.0, "ult_cd": 0.0, "boost": 0.0, "slow": 0.0,
            "dead": 0.0, "invulnerable": 1.0, "shots": 0, "charge": 0.0,
            "charge_angle": 0.0, "invisible": 0.0, "ghost_root": 0.0, "vine_root": 0.0, "ghost_channel": 0.0,
            "poison_normal": 0.0, "poison_ultimate": 0.0, "normal_tick": 0.1, "ultimate_tick": 0.1,
            "normal_source": 0, "ultimate_source": 0, "marks": {}, "burns": [], "pull": {}
        }

func spawn_position(team: int, index: int) -> Vector2:
    return Vector2(120.0 if team == 0 else WORLD.x - 120.0, 580.0 + 220.0 * index)

static func base_speed(tank: String) -> float:
    return {"steel": 135.0, "wing": 125.0, "ghost": 140.0, "elf": 135.0, "dark": 140.0}.get(tank, 135.0)

static func muzzle_offset(tank: String) -> float:
    return {"steel": 32.0, "wing": 47.0, "ghost": 47.0, "dark": 47.0, "elf": 45.0}.get(tank, MUZZLE_OFFSET)

static func wall_rects(chosen_map: String) -> Array:
    var result: Array = []
    for y in range(2):
        for x in range(2):
            for rect: Rect2 in MAPS.get(chosen_map, MAPS["ice"]):
                result.append(Rect2(rect.position + Vector2(x * TILE_SIZE.x, y * TILE_SIZE.y), rect.size))
    return result

func blocked(pos: Vector2, radius: float = 18.0) -> bool:
    if pos.x < radius or pos.y < radius or pos.x > WORLD.x - radius or pos.y > WORLD.y - radius:
        return true
    for obstacle: Rect2 in walls:
        if obstacle.grow(radius).has_point(pos):
            return true
    for obstacle in obstacles:
        if obstacle.hits > 0 and obstacle.rect.grow(radius).has_point(pos):
            return true
    return false

func obstacle_at(pos: Vector2, radius: float = 2.0) -> int:
    for i in range(obstacles.size()):
        if obstacles[i].hits > 0 and obstacles[i].rect.grow(radius).has_point(pos):
            return i
    return -1

func damage_obstacle(index: int) -> void:
    if index < 0 or index >= obstacles.size() or obstacles[index].hits <= 0:
        return
    obstacles[index].hits -= 1
    effects.append({"kind": "ice_hit", "position": obstacles[index].rect.get_center(), "life": 0.25})

func segment_blocked(from: Vector2, to: Vector2) -> bool:
    var length := from.distance_to(to)
    var steps := maxi(1, ceili(length / 5.0))
    for i in range(1, steps + 1):
        if blocked(from.lerp(to, float(i) / steps), 2.0):
            return true
    return false

func set_input(peer_id: int, direction: Vector2, angle: float, firing: bool) -> void:
    if not players.has(peer_id) or not is_finite(angle):
        return
    var player: Dictionary = players[peer_id]
    if not is_finite(direction.x) or not is_finite(direction.y):
        return
    player.direction = direction.limit_length(1.0)
    player.aim = wrapf(angle, -PI, PI) if player.charge <= 0.0 else player.charge_angle
    player.firing = firing

func use_ability(peer_id: int, action: String, target: Vector2) -> bool:
    if not running or not players.has(peer_id) or not is_finite(target.x) or not is_finite(target.y):
        return false
    var p: Dictionary = players[peer_id]
    if p.dead > 0.0 or p.charge > 0.0 or p.ghost_root > 0.0 or p.vine_root > 0.0 or p.ghost_channel > 0.0:
        return false
    if action == "boost" and p.tank == "steel" and p.e_cd <= 0.0:
        p.boost = 2.0
        p.e_cd = 9.0
        return true
    if action == "missile" and p.tank == "wing" and p.e_cd <= 0.0:
        if p.position.distance_to(target) > CAST_RANGE:
            return false
        var target_id := 0
        var found := false
        var target_obstacle := -1
        var closest := 36.0
        for other_id in players:
            var other: Dictionary = players[other_id]
            if other.team == p.team or other.dead > 0.0 or other.invisible > 0.0:
                continue
            var dist: float = other.position.distance_to(target)
            if dist < closest and p.position.distance_to(other.position) <= CAST_RANGE:
                closest = dist
                target_id = other_id
                found = true
        if not found:
            target_obstacle = obstacle_at(target, 8.0)
        if not found and target_obstacle < 0:
            return false
        for i in range(3):
            fields.append({"kind": "missile_pending", "owner": peer_id, "target_id": target_id, "target_obstacle": target_obstacle, "delay": i * 0.18})
        p.e_cd = 8.0
        return true
    if action == "dark_stealth" and p.tank == "dark" and p.e_cd <= 0.0:
        p.invisible = 5.0
        p.e_cd = 8.0
        return true
    if action == "ghost_ult" and p.tank == "ghost" and p.ult_cd <= 0.0:
        p.ghost_channel = 2.0
        p.ult_cd = 18.0
        fields.append({"kind": "ghost_zone", "owner": peer_id, "position": p.position, "life": 2.0, "tick": 0.0, "hits_left": 20})
        for other_id in players:
            var other: Dictionary = players[other_id]
            if other.team != p.team and other.dead <= 0.0 and other.invulnerable <= 0.0 and other.position.distance_to(p.position) <= GHOST_RADIUS:
                other.ghost_root = maxf(other.ghost_root, 2.0)
                other.pull.clear()
        return true
    if action in ["ghost_hook", "elf_arrow", "elf_ult", "dark_ult"]:
        if target.distance_squared_to(p.position) < 1.0:
            return false
        var angle: float = p.position.angle_to_point(target)
        if action == "ghost_hook" and p.tank == "ghost" and p.e_cd <= 0.0:
            spawn_projectile(p, angle, "ghost_hook", 650.0, GHOST_HOOK_RANGE, 100.0)
            p.e_cd = 8.0
            return true
        if action == "elf_arrow" and p.tank == "elf" and p.e_cd <= 0.0:
            spawn_projectile(p, angle, "elf_arrow", 760.0, ELF_ARROW_RANGE, 330.0)
            p.e_cd = 7.0
            return true
        if action == "elf_ult" and p.tank == "elf" and p.ult_cd <= 0.0:
            spawn_projectile(p, angle, "elf_ult", 690.0, ELF_ULT_RANGE, 250.0)
            p.ult_cd = 18.0
            return true
        if action == "dark_ult" and p.tank == "dark" and p.ult_cd <= 0.0:
            p.ult_cd = 18.0
            dark_ultimate(p, angle)
            return true
    if action == "ultimate" and p.tank in ["steel", "wing"] and p.ult_cd <= 0.0:
        if p.tank == "steel":
            if p.position.distance_to(target) > CAST_RANGE:
                return false
            fields.append({"kind": "bombard", "owner": peer_id, "position": target, "life": 3.0, "tick": 0.0, "hits_left": 30})
            p.ult_cd = 18.0
        else:
            if target.distance_squared_to(p.position) < 1.0:
                return false
            p.charge_angle = p.position.angle_to_point(target)
            p.aim = p.charge_angle
            p.charge = 1.0
            p.ult_cd = 16.0
        return true
    return false

func hit(target_id: int, amount: float, source_id: int, skill: bool = false, show_effect: bool = true) -> bool:
    if not players.has(target_id) or not players.has(source_id):
        return false
    var target: Dictionary = players[target_id]
    var source: Dictionary = players[source_id]
    if target.dead > 0.0 or target.invulnerable > 0.0 or target.team == source.team:
        return false
    if skill and source.tank == "elf" and target.marks.has(source_id):
        amount *= 1.5
    target.hp -= amount
    if show_effect:
        effects.append({"kind": "hit", "position": target.position, "life": 0.18})
    if target.hp <= 0.0:
        target.hp = 0.0
        target.dead = 4.0
        target.charge = 0.0
        score[source.team] += 1
        effects.append({"kind": "explosion", "position": target.position, "life": 0.5})
        if target.tank == "ghost":
            ghost_death(target)
    return true

func muzzle_position(origin: Vector2, dir: Vector2, offset: float = MUZZLE_OFFSET) -> Vector2:
    var last := origin
    for i in range(1, 22):
        var point := origin + dir * (offset * float(i) / 21.0)
        if blocked(point, 2.0):
            break
        last = point
    return last

func spawn_projectile(p: Dictionary, angle: float, kind: String, speed: float, distance: float, damage: float, pierce: bool = false, homing_target_id: int = 0, target_obstacle: int = -1) -> void:
    var dir := Vector2.RIGHT.rotated(angle)
    id_counter += 1
    var muzzle := muzzle_position(p.position, dir, muzzle_offset(p.tank))
    var bullet := {"id": id_counter, "owner": p.id, "position": muzzle, "velocity": dir * speed,
        "remaining": distance, "damage": damage, "pierce": pierce, "hits": [], "kind": kind}
    if kind == "elf_arrow":
        bullet["distance_total"] = distance
    if kind == "missile":
        bullet["target_id"] = homing_target_id
        bullet["target_obstacle"] = target_obstacle
    # A long visual muzzle must not skip enemies between the vehicle and muzzle.
    # Limit the check to the unobstructed part of the barrel.
    var near_targets: Array = []
    for target_id in players:
        var target: Dictionary = players[target_id]
        var relative: Vector2 = target.position - p.position
        var along := relative.dot(dir)
        if kind == "missile" and (target_obstacle >= 0 or target_id != bullet.target_id):
            continue
        if target.team != p.team and target.dead <= 0.0 and along >= 0.0 and along <= p.position.distance_to(muzzle) and absf(relative.cross(dir)) < 22.0:
            near_targets.append({"id": target_id, "distance": along})
    near_targets.sort_custom(func(a, b): return a.distance < b.distance)
    for entry in near_targets:
        bullet.hits.append(entry.id)
        apply_projectile_hit(bullet, entry.id)
        if not pierce:
            return
    bullets.append(bullet)

func fire(p: Dictionary) -> void:
    var dir := Vector2.RIGHT.rotated(p.aim)
    p.shots += 1
    var enhanced: bool = p.tank == "steel" and p.shots % 7 == 0
    var speed := 520.0 if p.tank == "steel" else 420.0
    var max_dist: float = 425.0 if enhanced else {"steel": 425.0 * 1.25, "wing": 1008.0, "ghost": GHOST_RANGE, "elf": ELF_SHOT_RANGE, "dark": DARK_SHOT_RANGE}[p.tank]
    var damage: float = 258.0 if enhanced else {"steel": 129.0, "wing": 148.0, "ghost": 120.0, "elf": 135.0, "dark": 120.0}[p.tank]
    var kind: String = {"steel": "bolt", "wing": "bolt", "ghost": "ghost_shot", "elf": "elf_shot", "dark": "dark_shot"}[p.tank]
    spawn_projectile(p, dir.angle(), kind, speed, max_dist, damage, enhanced)
    p.fire_cd = 0.34 if p.tank == "steel" else 0.30

func ghost_death(p: Dictionary) -> void:
    effects.append({"kind": "ghost_blast", "position": p.position, "life": 0.5})
    for id in players:
        var other: Dictionary = players[id]
        if other.team != p.team and other.dead <= 0.0 and other.position.distance_to(p.position) <= GHOST_RADIUS:
            if hit(id, 75.0, p.id, true) and other.dead <= 0.0:
                other.burns.append({"owner": p.id, "remaining": 2.0, "tick": 0.5})

func in_dark_cone(origin: Vector2, angle: float, point: Vector2) -> bool:
    var offset := point - origin
    return offset.length() <= DARK_ULT_RANGE and (offset.length_squared() < 1.0 or absf(wrapf(offset.angle() - angle, -PI, PI)) <= DARK_ULT_HALF_ANGLE)

func dark_ultimate(p: Dictionary, angle: float) -> void:
    effects.append({"kind": "bat_ult", "position": p.position, "angle": angle, "length": DARK_ULT_RANGE, "life": 0.6})
    for i in range(obstacles.size()):
        if obstacles[i].hits > 0 and in_dark_cone(p.position, angle, obstacles[i].rect.get_center()):
            damage_obstacle(i)
    for id in players:
        var other: Dictionary = players[id]
        if other.team != p.team and other.dead <= 0.0 and in_dark_cone(p.position, angle, other.position):
            if hit(id, 360.0, p.id, true) and other.dead <= 0.0:
                other.poison_ultimate = maxf(other.poison_ultimate, 5.0)
                other.ultimate_tick = 0.1
                other.ultimate_source = p.id

func apply_projectile_hit(bullet: Dictionary, target_id: int) -> void:
    if not players.has(target_id) or not players.has(bullet.owner):
        return
    var other: Dictionary = players[target_id]
    var owner: Dictionary = players[bullet.owner]
    var amount: float = bullet.damage
    var is_skill: bool = bullet.kind in ["ghost_hook", "elf_arrow", "elf_ult"]
    if bullet.kind == "elf_arrow":
        amount *= 1.0 + clampf((bullet.distance_total - bullet.remaining) / ELF_ARROW_RANGE, 0.0, 1.0)
    var applied := hit(target_id, amount, bullet.owner, is_skill)
    if not applied or other.dead > 0.0:
        return
    if bullet.kind == "elf_shot":
        other.marks[bullet.owner] = 3.0
    elif bullet.kind == "dark_shot":
        if other.poison_normal <= 0.0:
            other.normal_tick = 0.1
        other.poison_normal += 2.0
        other.normal_source = bullet.owner
    elif bullet.kind == "ghost_hook":
        other.pull = {"owner": bullet.owner}
    elif bullet.kind == "elf_ult":
        fields.append({"kind": "vine_zone", "owner": bullet.owner, "position": other.position, "life": 2.0})
        for victim_id in players:
            var victim: Dictionary = players[victim_id]
            if victim.team != owner.team and victim.dead <= 0.0 and victim.invulnerable <= 0.0 and victim.position.distance_to(other.position) <= VINE_RADIUS:
                victim.vine_root = maxf(victim.vine_root, 2.0)
                victim.slow = maxf(victim.slow, 2.0)
                victim.pull.clear()

func fire_laser(p: Dictionary) -> void:
    var origin: Vector2 = p.position
    var dir := Vector2.RIGHT.rotated(p.charge_angle)
    var distance := BEAM_RANGE
    var d := 5.0
    while d < BEAM_RANGE:
        if blocked(origin + dir * d, 2.0):
            distance = d
            var obstacle_index := obstacle_at(origin + dir * d)
            if obstacle_index >= 0:
                damage_obstacle(obstacle_index)
            break
        d += 5.0
    effects.append({"kind": "laser", "position": origin, "angle": p.charge_angle, "length": distance, "life": 0.3})
    for other_id in players:
        var other: Dictionary = players[other_id]
        if other.team == p.team or other.dead > 0.0:
            continue
        var delta: Vector2 = other.position - origin
        var along := delta.dot(dir)
        var across := absf(delta.cross(dir))
        if along >= 0.0 and along <= distance and across < 32.0:
            hit(other_id, 1200.0, p.id)

func step(delta: float) -> void:
    if not running:
        return
    var dt := clampf(delta, 0.0, 0.05)
    time_left = maxf(0.0, time_left - dt)
    for peer_id in players:
        var p: Dictionary = players[peer_id]
        for key in ["fire_cd", "e_cd", "ult_cd", "boost", "slow", "invulnerable", "invisible", "ghost_root", "vine_root", "ghost_channel"]:
            p[key] = maxf(0.0, float(p[key]) - dt)
        for source_id in p.marks.keys():
            p.marks[source_id] = float(p.marks[source_id]) - dt
            if p.marks[source_id] <= 0.0:
                p.marks.erase(source_id)
        if p.dead > 0.0:
            p.dead -= dt
            if p.dead <= 0.0:
                p.dead = 0.0
                p.hp = p.max_hp
                p.position = spawn_position(p.team, p.spawn_index)
                p.invulnerable = 2.0
                p.ghost_root = 0.0
                p.vine_root = 0.0
                p.ghost_channel = 0.0
                p.invisible = 0.0
                p.poison_normal = 0.0
                p.poison_ultimate = 0.0
                p.marks.clear()
                p.burns.clear()
                p.pull.clear()
            continue
        for poison in [["poison_normal", "normal_tick", "normal_source", .01], ["poison_ultimate", "ultimate_tick", "ultimate_source", .02]]:
            if p[poison[0]] > 0.0 and p.dead <= 0.0:
                var elapsed: float = minf(dt, p[poison[0]])
                p[poison[0]] = maxf(0.0, p[poison[0]] - elapsed)
                p[poison[1]] -= elapsed
                while p[poison[1]] <= 0.000001 and p.dead <= 0.0:
                    p[poison[1]] += 0.1
                    hit(peer_id, p.max_hp * float(poison[3]), p[poison[2]], false, false)
        for burn in p.burns:
            var elapsed: float = minf(dt, burn.remaining)
            burn.remaining -= elapsed
            burn.tick -= elapsed
            while burn.tick <= 0.000001 and p.dead <= 0.0:
                burn.tick += 0.5
                hit(peer_id, 35.0, burn.owner, true, false)
        p.burns = p.burns.filter(func(b): return b.remaining > 0.000001)
        if p.dead > 0.0:
            continue
        if p.charge > 0.0 and (p.ghost_root > 0.0 or p.vine_root > 0.0):
            p.charge = 0.0
        if p.charge > 0.0:
            p.charge -= dt
            p.aim = p.charge_angle
            if p.charge <= 0.0:
                p.charge = 0.0
                fire_laser(p)
            continue
        # Hull orientation follows movement input independently of turret aim.
        # Dead and charging tanks skip this update, and an idle tank keeps its heading.
        var rooted: bool = p.ghost_root > 0.0 or p.vine_root > 0.0 or p.ghost_channel > 0.0
        if not rooted and not p.pull.is_empty() and players.has(p.pull.owner):
            var pull_offset: Vector2 = players[p.pull.owner].position - p.position
            if pull_offset.length() <= 45.0:
                p.pull.clear()
            else:
                var pull_step: Vector2 = pull_offset.normalized() * minf(350.0 * dt, pull_offset.length() - 45.0)
                if blocked(p.position + pull_step):
                    p.pull.clear()
                else:
                    p.position += pull_step
        if not rooted and p.pull.is_empty() and p.direction.length_squared() > 0.000001:
            p.hull_angle = p.direction.angle()
        var speed: float = 270.0 if p.boost > 0.0 else base_speed(p.tank)
        if p.slow > 0.0:
            speed *= 0.5
        if not rooted and p.pull.is_empty():
            var next: Vector2 = p.position + p.direction * speed * dt
            if not blocked(Vector2(next.x, p.position.y)):
                p.position.x = next.x
            if not blocked(Vector2(p.position.x, next.y)):
                p.position.y = next.y
        if p.firing and p.fire_cd <= 0.0 and p.ghost_root <= 0.0 and p.ghost_channel <= 0.0:
            fire(p)
    for field in fields:
        if not players.has(field.owner):
            field["remove"] = true
            continue
        var owner: Dictionary = players[field.owner]
        if field.kind == "missile_pending":
            field.delay -= dt
            if field.delay <= 0.0:
                var target_position := Vector2.ZERO
                var valid_target := false
                if field.target_obstacle >= 0 and field.target_obstacle < obstacles.size() and obstacles[field.target_obstacle].hits > 0:
                    target_position = obstacles[field.target_obstacle].rect.get_center()
                    valid_target = true
                elif field.target_obstacle < 0 and players.has(field.target_id) and players[field.target_id].dead <= 0.0 and players[field.target_id].invisible <= 0.0:
                    target_position = players[field.target_id].position
                    valid_target = true
                if owner.dead <= 0.0 and valid_target:
                    var to_target: Vector2 = (target_position - owner.position).normalized()
                    spawn_projectile(owner, to_target.angle(), "missile", 350.0, 1400.0, 240.0, false, field.target_id, field.target_obstacle)
                field["remove"] = true
        elif field.kind == "bombard":
            field.tick -= dt
            while field.tick <= 0.0 and field.hits_left > 0:
                field.tick += 0.1
                field.hits_left -= 1
                for other_id in players:
                    var other: Dictionary = players[other_id]
                    if other.team != owner.team and other.dead <= 0.0 and other.position.distance_to(field.position) < 100.0:
                        hit(other_id, owner.max_hp / 60.0, field.owner)
                        other.slow = 1.0
            field.life -= dt
            if field.life <= 0.00001:
                field["remove"] = true
        elif field.kind == "ghost_zone":
            if owner.dead > 0.0 or owner.ghost_root > 0.0 or owner.vine_root > 0.0:
                owner.ghost_channel = 0.0
                field["remove"] = true
                continue
            if not field.has("victims"):
                field["victims"] = []
            for other_id in players:
                var other: Dictionary = players[other_id]
                if other.team != owner.team and other.dead <= 0.0 and other.invulnerable <= 0.0 and other.position.distance_to(field.position) <= GHOST_RADIUS:
                    other.ghost_root = maxf(other.ghost_root, field.life)
                    other.pull.clear()
                    if other_id not in field.victims:
                        field.victims.append(other_id)
            field.tick -= dt
            while field.tick <= 0.000001 and field.hits_left > 0:
                field.tick += 0.1
                field.hits_left -= 1
                for other_id in field.victims:
                    if players.has(other_id) and players[other_id].dead <= 0.0:
                        hit(other_id, 80.0, field.owner, true, false)
            field.life -= dt
            if field.life <= 0.00001:
                field["remove"] = true
        elif field.kind == "vine_zone":
            for other_id in players:
                var other: Dictionary = players[other_id]
                if other.team != owner.team and other.dead <= 0.0 and other.invulnerable <= 0.0 and other.position.distance_to(field.position) <= VINE_RADIUS:
                    other.vine_root = maxf(other.vine_root, field.life)
                    other.slow = maxf(other.slow, field.life)
                    other.pull.clear()
            field.life -= dt
            if field.life <= 0.00001:
                field["remove"] = true
    fields = fields.filter(func(f): return not f.get("remove", false))
    for bullet in bullets:
        if not players.has(bullet.owner):
            bullet["remove"] = true
            continue
        var owner: Dictionary = players[bullet.owner]
        if bullet.kind == "missile":
            var missile_target := Vector2.ZERO
            if bullet.target_obstacle >= 0:
                if obstacles[bullet.target_obstacle].hits <= 0:
                    bullet["remove"] = true
                    continue
                missile_target = obstacles[bullet.target_obstacle].rect.get_center()
            elif players.has(bullet.target_id) and players[bullet.target_id].dead <= 0.0 and players[bullet.target_id].invisible <= 0.0:
                missile_target = players[bullet.target_id].position
            else:
                bullet["remove"] = true
                continue
            bullet.velocity = (missile_target - bullet.position).normalized() * 350.0
        var previous: Vector2 = bullet.position
        var travel: Vector2 = bullet.velocity * dt
        bullet.position += travel
        bullet.remaining -= travel.length()
        if not bullet.has("obstacle_hits"):
            bullet["obstacle_hits"] = []
        var steps := maxi(1, ceili(travel.length() / 4.0))
        for i in range(1, steps + 1):
            var point := previous.lerp(bullet.position, float(i) / steps)
            var obstacle_index := obstacle_at(point)
            var was_blocked := blocked(point, 2.0)
            if obstacle_index >= 0 and obstacle_index not in bullet.obstacle_hits:
                bullet.obstacle_hits.append(obstacle_index)
                damage_obstacle(obstacle_index)
            if not bullet.pierce and was_blocked:
                bullet["remove"] = true
                break
        if bullet.remaining <= 0.0 or bullet.get("remove", false):
            bullet["remove"] = true
            continue
        for other_id in players:
            var other: Dictionary = players[other_id]
            if other.team == owner.team or other.dead > 0.0 or other_id in bullet.hits:
                continue
            if bullet.kind == "missile" and other_id != bullet.target_id:
                continue
            if Geometry2D.get_closest_point_to_segment(other.position, previous, bullet.position).distance_to(other.position) < 22.0:
                bullet.hits.append(other_id)
                apply_projectile_hit(bullet, other_id)
                if not bullet.pierce:
                    bullet["remove"] = true
                    break
    bullets = bullets.filter(func(b): return not b.get("remove", false))
    for effect in effects:
        effect.life -= dt
    effects = effects.filter(func(e): return e.life > 0.0)
    if time_left <= 0.0 or score[0] >= 25 or score[1] >= 25:
        running = false
        round_over = true

func snapshot() -> Dictionary:
    return {"players": players.duplicate(true), "bullets": bullets.duplicate(true), "effects": effects.duplicate(true),
        "fields": fields.duplicate(true), "obstacles": obstacles.duplicate(true), "map_id": map_id, "time_left": time_left, "score": score.duplicate(), "round_over": round_over}
