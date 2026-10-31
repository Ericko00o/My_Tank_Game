class_name ArenaSimulation
extends RefCounted

const WORLD := Vector2(2560, 1440)
const TILE_SIZE := Vector2(1280, 720)
const STEEL_MAX := 1227.0
const WING_MAX := 1296.0
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
        if tank != "steel" and tank != "wing":
            tank = "steel"
        var peer_id: int = int(entry.get("id", 1))
        var max_hp: float = STEEL_MAX if tank == "steel" else WING_MAX
        players[peer_id] = {
            "id": peer_id, "name": str(entry.get("name", "Player")).substr(0, 14),
            "team": team, "tank": tank, "position": spawn_position(team, index),
            "spawn_index": index, "hp": max_hp, "max_hp": max_hp,
            "direction": Vector2.ZERO, "aim": 0.0, "hull_angle": 0.0, "firing": false, "fire_cd": 0.0,
            "e_cd": 0.0, "ult_cd": 0.0, "boost": 0.0, "slow": 0.0,
            "dead": 0.0, "invulnerable": 1.0, "shots": 0, "charge": 0.0,
            "charge_angle": 0.0
        }

func spawn_position(team: int, index: int) -> Vector2:
    return Vector2(120.0 if team == 0 else WORLD.x - 120.0, 580.0 + 220.0 * index)

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
    if p.dead > 0.0 or p.charge > 0.0:
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
            if other.team == p.team or other.dead > 0.0:
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
    if action == "ultimate" and p.ult_cd <= 0.0:
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

func hit(target_id: int, amount: float, source_id: int) -> void:
    if not players.has(target_id) or not players.has(source_id):
        return
    var target: Dictionary = players[target_id]
    var source: Dictionary = players[source_id]
    if target.dead > 0.0 or target.invulnerable > 0.0 or target.team == source.team:
        return
    target.hp -= amount
    effects.append({"kind": "hit", "position": target.position, "life": 0.18})
    if target.hp <= 0.0:
        target.hp = 0.0
        target.dead = 4.0
        target.charge = 0.0
        score[source.team] += 1
        effects.append({"kind": "explosion", "position": target.position, "life": 0.5})

func fire(p: Dictionary) -> void:
    var dir := Vector2.RIGHT.rotated(p.aim)
    p.shots += 1
    var enhanced: bool = p.tank == "steel" and p.shots % 7 == 0
    var speed := 520.0 if p.tank == "steel" else 420.0
    var max_dist := 425.0 if enhanced else (425.0 * 1.25 if p.tank == "steel" else 1008.0)
    id_counter += 1
    bullets.append({"id": id_counter, "owner": p.id, "position": p.position + dir * 27.0, "velocity": dir * speed,
        "remaining": max_dist, "damage": 258.0 if enhanced else (129.0 if p.tank == "steel" else 148.0),
        "pierce": enhanced, "hits": [], "kind": "bolt"})
    p.fire_cd = 0.34 if p.tank == "steel" else 0.30

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
        for key in ["fire_cd", "e_cd", "ult_cd", "boost", "slow", "invulnerable"]:
            p[key] = maxf(0.0, float(p[key]) - dt)
        if p.dead > 0.0:
            p.dead -= dt
            if p.dead <= 0.0:
                p.dead = 0.0
                p.hp = p.max_hp
                p.position = spawn_position(p.team, p.spawn_index)
                p.invulnerable = 2.0
            continue
        if p.charge > 0.0:
            p.charge -= dt
            p.aim = p.charge_angle
            if p.charge <= 0.0:
                p.charge = 0.0
                fire_laser(p)
            continue
        # Hull orientation follows movement input independently of turret aim.
        # Dead and charging tanks skip this update, and an idle tank keeps its heading.
        if p.direction.length_squared() > 0.000001:
            p.hull_angle = p.direction.angle()
        var speed: float = 270.0 if p.boost > 0.0 else (135.0 if p.tank == "steel" else 125.0)
        if p.slow > 0.0:
            speed *= 0.5
        var next: Vector2 = p.position + p.direction * speed * dt
        if not blocked(Vector2(next.x, p.position.y)):
            p.position.x = next.x
        if not blocked(Vector2(p.position.x, next.y)):
            p.position.y = next.y
        if p.firing and p.fire_cd <= 0.0:
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
                elif field.target_obstacle < 0 and players.has(field.target_id) and players[field.target_id].dead <= 0.0:
                    target_position = players[field.target_id].position
                    valid_target = true
                if owner.dead <= 0.0 and valid_target:
                    var to_target: Vector2 = (target_position - owner.position).normalized()
                    id_counter += 1
                    bullets.append({"id": id_counter, "owner": field.owner, "position": owner.position + to_target * 25.0,
                        "velocity": to_target * 350.0, "remaining": 1400.0, "damage": 240.0,
                        "pierce": false, "hits": [], "kind": "missile", "target_id": field.target_id, "target_obstacle": field.target_obstacle})
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
            elif players.has(bullet.target_id) and players[bullet.target_id].dead <= 0.0:
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
                hit(other_id, bullet.damage, bullet.owner)
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
