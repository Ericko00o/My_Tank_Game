extends Node2D

const Sim = preload("res://scripts/simulation.gd")
const STEEL_TEXTURE = preload("res://assets/steel.png")
const WING_TEXTURE = preload("res://assets/wing.png")
const ICE_FLOOR = preload("res://assets/ice_floor.png")
const JUNGLE_FLOOR = preload("res://assets/jungle_floor.png")
const ICE_BLOCK = preload("res://assets/ice_block.svg")
const PORT := 23456
const MAX_PLAYERS := 4
const SEND_INTERVAL := 0.05

var sim = Sim.new()
var view_state: Dictionary = {}
var roster: Array = []
var networked := false
var is_host := false
var in_match := false
var practice := false
var local_id := 1
var aim_mode := ""
var send_timer := 0.0
var snapshot_timer := 0.0
var visual_positions: Dictionary = {}
var prediction_ready := false
var mouse_down := false
var selected_tank := "steel"
var selected_map := "ice"

var ui: CanvasLayer
var panel: PanelContainer
var name_field: LineEdit
var ip_field: LineEdit
var tank_choice: OptionButton
var map_choice: OptionButton
var host_button: Button
var join_button: Button
var practice_button: Button
var start_button: Button
var cancel_button: Button
var notice: Label
var roster_label: Label
var hud: Label
var instruction: Label
var exit_button: Button

func _ready() -> void:
    _build_ui()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    queue_redraw()

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    panel = PanelContainer.new()
    panel.position = Vector2(385, 56)
    panel.size = Vector2(510, 604)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("10243a")
    style.border_color = Color("4d91a8")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    style.content_margin_left = 28
    style.content_margin_right = 28
    style.content_margin_top = 18
    style.content_margin_bottom = 18
    panel.add_theme_stylebox_override("panel", style)
    ui.add_child(panel)
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 9)
    panel.add_child(list)
    var title := Label.new()
    title.text = "坦 克 競 技 場"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color("f9d97e"))
    list.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "GODOT  ·  LAN VERTICAL SLICE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 12)
    subtitle.modulate = Color("99c7d7")
    list.add_child(subtitle)
    name_field = LineEdit.new()
    name_field.placeholder_text = "玩家名稱"
    name_field.text = "玩家"
    name_field.max_length = 14
    list.add_child(_row("玩家", name_field))
    tank_choice = OptionButton.new()
    tank_choice.add_item("鋼鐵 · 範圍轟炸", 0)
    tank_choice.add_item("飛翼 · 鐳射大炮", 1)
    list.add_child(_row("坦克", tank_choice))
    map_choice = OptionButton.new()
    map_choice.add_item("冰天雪地", 0)
    map_choice.add_item("雨林古跡", 1)
    list.add_child(_row("地圖", map_choice))
    ip_field = LineEdit.new()
    ip_field.text = "127.0.0.1"
    ip_field.placeholder_text = "房主的區域網路 IP"
    list.add_child(_row("房主 IP", ip_field))
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 8)
    list.add_child(buttons)
    host_button = _button("建立房間", buttons)
    join_button = _button("加入房間", buttons)
    practice_button = _button("單人練習", buttons)
    start_button = _button("開始對戰", list)
    start_button.disabled = true
    cancel_button = _button("離開房間", list)
    cancel_button.hide()
    roster_label = Label.new()
    roster_label.text = "尚未建立房間"
    roster_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    roster_label.custom_minimum_size.y = 48
    list.add_child(roster_label)
    notice = Label.new()
    notice.text = "選擇坦克和地圖後建立房間，或加入房主。"
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.custom_minimum_size.y = 40
    notice.add_theme_color_override("font_color", Color("a3d1d3"))
    list.add_child(notice)
    var help := Label.new()
    help.text = "WASD / 方向鍵移動 · 滑鼠瞄準 · 左鍵普攻
E 小技能 · 空白鍵大招 · Esc 取消瞄準"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.add_theme_font_size_override("font_size", 14)
    help.modulate = Color("b7cad1")
    list.add_child(help)
    host_button.pressed.connect(_host_room)
    join_button.pressed.connect(_join_room)
    practice_button.pressed.connect(_start_practice)
    start_button.pressed.connect(_start_match)
    cancel_button.pressed.connect(_return_to_menu)
    hud = Label.new()
    hud.position = Vector2(410, 12)
    hud.size = Vector2(460, 46)
    hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.add_theme_font_size_override("font_size", 24)
    hud.add_theme_color_override("font_color", Color("ffffff"))
    hud.add_theme_constant_override("shadow_offset_x", 2)
    hud.add_theme_constant_override("shadow_offset_y", 2)
    ui.add_child(hud)
    instruction = Label.new()
    instruction.position = Vector2(225, 670)
    instruction.size = Vector2(830, 35)
    instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    instruction.add_theme_font_size_override("font_size", 16)
    instruction.add_theme_color_override("font_color", Color("ffffff"))
    ui.add_child(instruction)
    exit_button = Button.new()
    exit_button.text = "返回大廳"
    exit_button.position = Vector2(1120, 12)
    exit_button.size = Vector2(140, 40)
    exit_button.pressed.connect(_return_to_menu)
    ui.add_child(exit_button)
    hud.hide()
    instruction.hide()
    exit_button.hide()

func _row(caption: String, child: Control) -> HBoxContainer:
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = caption
    label.custom_minimum_size.x = 86
    row.add_child(label)
    child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    child.custom_minimum_size.y = 34
    row.add_child(child)
    return row

func _button(text: String, parent: Node) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 38
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(button)
    return button

func _name() -> String:
    var value := name_field.text.strip_edges()
    return "玩家" if value.is_empty() else value.substr(0, 14)

func _tank() -> String:
    return "steel" if tank_choice.selected == 0 else "wing"

func _map() -> String:
    return "ice" if map_choice.selected == 0 else "jungle"

func _host_room() -> void:
    _close_network()
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(PORT, MAX_PLAYERS - 1)
    if err != OK:
        notice.text = "無法建立房間（錯誤 %s）。請確認 UDP %s 可使用。" % [err, PORT]
        return
    multiplayer.multiplayer_peer = peer
    networked = true
    is_host = true
    practice = false
    local_id = 1
    selected_map = _map()
    roster = [{"id": 1, "name": _name(), "tank": _tank(), "team": 0}]
    _lock_lobby(true)
    notice.text = "房間已建立。房主 IP：%s（UDP %s）" % [_local_addresses(), PORT]
    _refresh_roster()

func _join_room() -> void:
    _close_network()
    var ip := ip_field.text.strip_edges()
    if ip.is_empty():
        notice.text = "請輸入房主的 IP。"
        return
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(ip, PORT)
    if err != OK:
        notice.text = "無法開始連線（錯誤 %s）。" % err
        return
    multiplayer.multiplayer_peer = peer
    networked = true
    is_host = false
    practice = false
    _lock_lobby(true)
    notice.text = "正在連線至 %s:%s …" % [ip, PORT]

func _local_addresses() -> String:
    var found := PackedStringArray()
    for address in IP.get_local_addresses():
        if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
            found.append(address)
    return "、".join(found) if not found.is_empty() else "請使用 ipconfig 查詢"

func _lock_lobby(locked: bool) -> void:
    cancel_button.visible = locked
    host_button.disabled = locked
    join_button.disabled = locked
    practice_button.disabled = locked
    name_field.editable = not locked
    tank_choice.disabled = locked
    map_choice.disabled = locked
    ip_field.editable = not locked

func _on_connected() -> void:
    local_id = multiplayer.get_unique_id()
    _register.rpc_id(1, _name(), _tank())

func _on_connection_failed() -> void:
    _close_network()
    notice.text = "連線失敗。請確認房主已建立房間、IP 及 UDP 埠。"

func _on_server_disconnected() -> void:
    _return_to_menu()
    notice.text = "房主已離線，房間已關閉。"

func _on_peer_connected(_id: int) -> void:
    pass

func _on_peer_disconnected(id: int) -> void:
    if is_host:
        roster = roster.filter(func(entry): return int(entry.id) != id)
        sim.players.erase(id)
        if not in_match:
            _broadcast_lobby()
        else:
            notice.text = "有玩家離開了對戰。"

@rpc("any_peer", "call_remote", "reliable")
func _register(player_name: String, tank: String) -> void:
    if not is_host or in_match:
        return
    var id := multiplayer.get_remote_sender_id()
    if roster.size() >= MAX_PLAYERS or roster.any(func(entry): return int(entry.id) == id):
        return
    var safe_tank := tank if tank in ["steel", "wing"] else "steel"
    roster.append({"id": id, "name": player_name.substr(0, 14), "tank": safe_tank, "team": roster.size() % 2})
    _broadcast_lobby()

func _broadcast_lobby() -> void:
    _refresh_roster()
    if networked and is_host and not multiplayer.get_peers().is_empty():
        _receive_lobby.rpc(roster, selected_map)

@rpc("authority", "call_remote", "reliable")
func _receive_lobby(data: Array, map_id: String) -> void:
    roster = data
    selected_map = map_id
    _refresh_roster()
    notice.text = "已加入房間，等待房主開始。"

func _refresh_roster() -> void:
    var parts := PackedStringArray()
    for entry in roster:
        var team_name := "藍" if int(entry.team) == 0 else "紅"
        var tank_name := "鋼鐵" if entry.tank == "steel" else "飛翼"
        parts.append("%s：%s（%s）" % [team_name, entry.name, tank_name])
    roster_label.text = "房間 %s/%s  ·  %s
%s" % [roster.size(), MAX_PLAYERS, "冰天雪地" if selected_map == "ice" else "雨林古跡", "   ".join(parts)]
    start_button.disabled = not is_host or not roster.size() in [2, 4]

func _start_practice() -> void:
    _close_network()
    practice = true
    is_host = true
    selected_map = _map()
    roster = [{"id": 1, "name": _name(), "tank": _tank(), "team": 0},
        {"id": -1, "name": "練習對手", "tank": "wing", "team": 1}]
    _begin_match(roster, selected_map)

func _start_match() -> void:
    if not is_host or not roster.size() in [2, 4]:
        return
    _begin_match(roster, selected_map)
    if networked:
        _receive_match.rpc(roster, selected_map)

@rpc("authority", "call_remote", "reliable")
func _receive_match(data: Array, map_id: String) -> void:
    roster = data
    selected_map = map_id
    _begin_match(data, map_id)

func _begin_match(data: Array, map_id: String) -> void:
    in_match = true
    visual_positions.clear()
    prediction_ready = false
    sim.map_id = map_id
    aim_mode = ""
    mouse_down = false
    panel.hide()
    hud.show()
    instruction.show()
    exit_button.show()
    if is_host:
        sim.setup(data, map_id)
        view_state = sim.snapshot()
    else:
        view_state = {}
    queue_redraw()

func _return_to_menu() -> void:
    _close_network()
    in_match = false
    practice = false
    aim_mode = ""
    mouse_down = false
    roster.clear()
    view_state.clear()
    visual_positions.clear()
    prediction_ready = false
    panel.show()
    hud.hide()
    instruction.hide()
    exit_button.hide()
    roster_label.text = "尚未建立房間"
    queue_redraw()

func _close_network() -> void:
    if networked and multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    networked = false
    is_host = false
    local_id = 1
    _lock_lobby(false)
    start_button.disabled = true

func _process(delta: float) -> void:
    if not in_match:
        return
    if is_host:
        if sim.players.has(1):
            _apply_local_input(sim.players[1])
        if practice:
            _practice_ai()
        sim.step(delta)
        view_state = sim.snapshot()
        if networked:
            snapshot_timer += delta
            if snapshot_timer >= SEND_INTERVAL:
                snapshot_timer = 0.0
                if not multiplayer.get_peers().is_empty():
                    var packed := var_to_bytes(view_state).compress(FileAccess.COMPRESSION_DEFLATE)
                    _receive_snapshot.rpc(packed)
    elif networked and view_state.has("players"):
        _predict_client(delta)
        send_timer += delta
        if send_timer >= SEND_INTERVAL:
            send_timer = 0.0
            var input := _gather_input()
            _receive_input.rpc_id(1, input.direction, input.angle, input.firing)
    _update_hud()
    queue_redraw()

func _gather_input() -> Dictionary:
    var direction := Vector2(
        float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
        float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    ).limit_length(1.0)
    var position := Vector2(120, 250)
    if view_state.has("players") and view_state.players.has(local_id):
        position = visual_positions.get(local_id, view_state.players[local_id].position)
    var angle := position.angle_to_point(get_global_mouse_position())
    return {"direction": direction, "angle": angle, "firing": mouse_down and aim_mode.is_empty()}

func _apply_local_input(_p: Dictionary) -> void:
    var input := _gather_input()
    sim.set_input(1, input.direction, input.angle, input.firing)

func _practice_ai() -> void:
    if not sim.players.has(-1) or not sim.players.has(1):
        return
    var bot: Dictionary = sim.players[-1]
    var player: Dictionary = sim.players[1]
    var offset: Vector2 = player.position - bot.position
    sim.set_input(-1, offset.normalized() if offset.length() > 360.0 else Vector2.ZERO, offset.angle(), offset.length() < 700.0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_input(direction: Vector2, angle: float, firing: bool) -> void:
    if is_host and in_match:
        sim.set_input(multiplayer.get_remote_sender_id(), direction, angle, firing)

@rpc("any_peer", "call_remote", "reliable")
func _request_ability(action: String, target: Vector2) -> void:
    if is_host and in_match:
        sim.use_ability(multiplayer.get_remote_sender_id(), action, target)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_snapshot(packed: PackedByteArray) -> void:
    var raw := packed.decompress_dynamic(2000000, FileAccess.COMPRESSION_DEFLATE)
    var data = bytes_to_var(raw)
    if not data is Dictionary:
        return
    if data.has("players") and data.players.has(local_id):
        var player: Dictionary = data.players[local_id]
        var actual: Vector2 = player.position
        var current: Vector2 = visual_positions.get(local_id, actual)
        if not prediction_ready or player.dead > 0.0 or current.distance_to(actual) > 100.0:
            visual_positions[local_id] = actual
        else:
            visual_positions[local_id] = current.lerp(actual, 0.25)
        prediction_ready = true
    sim.obstacles = data.get("obstacles", []).duplicate(true)
    view_state = data

func _predict_client(delta: float) -> void:
    if view_state.get("round_over", false):
        return
    var players: Dictionary = view_state.players
    if not players.has(local_id):
        return
    var p: Dictionary = players[local_id]
    var actual: Vector2 = p.position
    var current: Vector2 = visual_positions.get(local_id, actual)
    if p.dead <= 0.0 and p.charge <= 0.0:
        var input := _gather_input()
        var speed: float = 270.0 if p.boost > 0.0 else (135.0 if p.tank == "steel" else 125.0)
        if p.slow > 0.0:
            speed *= 0.5
        var next: Vector2 = current + input.direction * speed * minf(delta, .05)
        if not sim.blocked(Vector2(next.x, current.y)):
            current.x = next.x
        if not sim.blocked(Vector2(current.x, next.y)):
            current.y = next.y
    visual_positions[local_id] = current
    for peer_id in players:
        if peer_id == local_id:
            continue
        var target: Vector2 = players[peer_id].position
        var old: Vector2 = visual_positions.get(peer_id, target)
        visual_positions[peer_id] = old.lerp(target, 1.0 - exp(-18.0 * delta))

func _send_ability(action: String, target: Vector2) -> void:
    if is_host:
        sim.use_ability(1, action, target)
    elif networked:
        _request_ability.rpc_id(1, action, target)

func _unhandled_input(event: InputEvent) -> void:
    if not in_match:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        var key := event as InputEventKey
        if key.keycode == KEY_ESCAPE:
            aim_mode = ""
        elif key.keycode == KEY_E:
            var player := _local_player()
            if not player.is_empty() and player.dead <= 0.0 and player.e_cd <= 0.0:
                if player.tank == "steel":
                    _send_ability("boost", Vector2.ZERO)
                else:
                    aim_mode = "" if aim_mode == "missile" else "missile"
        elif key.keycode == KEY_SPACE:
            var player := _local_player()
            if not player.is_empty() and player.dead <= 0.0 and player.ult_cd <= 0.0:
                aim_mode = "" if aim_mode == "ultimate" else "ultimate"
    elif event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.button_index == MOUSE_BUTTON_LEFT:
            if click.pressed and not aim_mode.is_empty():
                var p := _local_player()
                var target := get_global_mouse_position()
                if not p.is_empty() and (p.tank != "steel" or aim_mode != "ultimate" or p.position.distance_to(target) <= Sim.CAST_RANGE):
                    _send_ability(aim_mode, target)
                    aim_mode = ""
                mouse_down = false
            else:
                mouse_down = click.pressed

func _local_player() -> Dictionary:
    if not view_state.has("players"):
        return {}
    return view_state.players.get(local_id, {})

func _update_hud() -> void:
    if view_state.is_empty():
        hud.text = "正在同步戰場…"
        return
    var p := _local_player()
    var seconds := ceili(float(view_state.time_left))
    hud.text = "藍  %s     %02d:%02d     %s  紅" % [view_state.score[0], seconds / 60, seconds % 60, view_state.score[1]]
    if p.is_empty():
        instruction.text = "等待同步"
    elif p.dead > 0.0:
        instruction.text = "坦克已陣亡 · %s 秒後復活" % ceili(p.dead)
    else:
        var e_text := "就緒" if p.e_cd <= 0 else "%s 秒" % ceili(p.e_cd)
        var ult_text := "就緒" if p.ult_cd <= 0 else "%s 秒" % ceili(p.ult_cd)
        instruction.text = "生命 %s / %s    E %s    空白 %s" % [roundi(p.hp), roundi(p.max_hp), e_text, ult_text]
        if not aim_mode.is_empty():
            instruction.text += "     左鍵確認 · Esc 取消"
    if view_state.get("round_over", false):
        instruction.text = "戰鬥結束 · 藍 %s : %s 紅     按右上角返回大廳" % [view_state.score[0], view_state.score[1]]

func _draw() -> void:
    var map_id := str(view_state.get("map_id", selected_map))
    var jungle := map_id == "jungle"
    var floor_texture: Texture2D = JUNGLE_FLOOR if jungle else ICE_FLOOR
    draw_texture_rect(floor_texture, Rect2(Vector2.ZERO, Sim.WORLD), false)
    draw_rect(Rect2(Vector2.ZERO, Sim.WORLD), Color(0.04, 0.10, 0.12, 0.16))
    for i in range(90):
        var point := Vector2((i * 191 + 13) % 1280, (i * 137 + 49) % 720)
        var color := Color(0.55, 0.76, 0.4, 0.20) if jungle else Color(0.8, 0.95, 1.0, 0.26)
        draw_circle(point, 2.0 + i % 3, color)
    for obstacle: Rect2 in Sim.MAPS.get(map_id, Sim.MAPS["ice"]):
        var top_color := Color("aab393") if jungle else Color("d2eef1")
        var side_color := Color("58715a") if jungle else Color("5b9bb8")
        draw_rect(Rect2(obstacle.position + Vector2(5, 8), obstacle.size), Color(0.05, 0.11, 0.15, 0.45))
        draw_rect(obstacle, side_color)
        draw_rect(Rect2(obstacle.position, obstacle.size - Vector2(0, 8)), top_color)
        draw_rect(Rect2(obstacle.position + Vector2(3, 3), obstacle.size - Vector2(6, 14)), Color(1, 1, 1, 0.22), false, 2.0)
        if jungle:
            for x in range(14, int(obstacle.size.x), 30):
                draw_line(obstacle.position + Vector2(x, 4), obstacle.position + Vector2(x - 5, 24), Color("71945e"), 3.0)
        else:
            for x in range(15, int(obstacle.size.x), 32):
                draw_circle(obstacle.position + Vector2(x, 3), 5.0, Color("f8ffff"))
    if in_match:
        for obstacle in view_state.get("obstacles", []):
            if obstacle.hits <= 0:
                continue
            var rect: Rect2 = obstacle.rect
            draw_texture_rect(ICE_BLOCK, rect, false, Color("a8d59b") if jungle else Color.WHITE)
            draw_rect(Rect2(rect.position + Vector2(3, -8), Vector2(rect.size.x - 6, 4)), Color(0.04, 0.12, 0.18, 0.8))
            draw_rect(Rect2(rect.position + Vector2(3, -8), Vector2((rect.size.x - 6) * float(obstacle.hits) / Sim.OBSTACLE_HITS, 4)), Color("9defff"))
    for team in [0, 1]:
        var spawn := Sim.new().spawn_position(team, 0)
        draw_arc(spawn, 75.0, 0.0, TAU, 48, Color("87e8f7") if team == 0 else Color("fa8a76"), 2.0, true)
    if not in_match or view_state.is_empty():
        return
    for field in view_state.get("fields", []):
        if field.kind == "bombard":
            var center: Vector2 = field.position
            draw_circle(center, 100.0, Color(1.0, 0.28, 0.06, 0.17))
            draw_arc(center, 100.0, 0.0, TAU, 64, Color("ffd27b"), 3.0, true)
            var phase := float(Time.get_ticks_msec() % 500) / 500.0
            for i in range(5):
                var offset := Vector2.from_angle(float(i) * TAU / 5.0 + phase) * (25.0 + 35.0 * phase)
                draw_line(center + offset + Vector2(-8, -20), center + offset, Color("ffe8a4"), 3.0, true)
                draw_circle(center + offset, 4.0, Color("ff914a"))
    for bullet in view_state.get("bullets", []):
        var position: Vector2 = bullet.position
        var direction: Vector2 = bullet.velocity.normalized()
        if bullet.kind == "missile":
            draw_line(position - direction * 20.0, position, Color("ffbc5d"), 5.0, true)
            draw_colored_polygon(PackedVector2Array([position + direction * 10.0, position - direction * 7.0 + direction.orthogonal() * 5.0, position - direction * 7.0 - direction.orthogonal() * 5.0]), Color("f6eee1"))
        else:
            var tint := Color("ffe174") if bullet.pierce else (Color("ff6c6c") if view_state.players[bullet.owner].tank == "steel" else Color("e5fbff"))
            draw_line(position - direction * (35.0 if bullet.pierce else 15.0), position + direction * 7.0, tint, 6.0 if bullet.pierce else 4.0, true)
    for effect in view_state.get("effects", []):
        var position: Vector2 = effect.position
        if effect.kind == "laser":
            var end := position + Vector2.RIGHT.rotated(effect.angle) * float(effect.length)
            draw_line(position, end, Color(0.14, 0.91, 1, 0.35), 58.0, true)
            draw_line(position, end, Color("89f9ff"), 26.0, true)
            draw_line(position, end, Color.WHITE, 8.0, true)
        elif effect.kind == "explosion":
            draw_circle(position, 30.0 * float(effect.life) / 0.5, Color(1, .5, .15, .7))
        elif effect.kind == "hit":
            draw_arc(position, 25.0, 0.0, TAU, 20, Color("fff3b2"), 3.0, true)
        elif effect.kind == "ice_hit":
            draw_arc(position, 24.0, 0.0, TAU, 20, Color("c3faff"), 3.0, true)
    for peer_id in view_state.players:
        var player: Dictionary = view_state.players[peer_id]
        if player.dead > 0.0:
            continue
        var visual_player := player.duplicate()
        if not is_host:
            visual_player.position = visual_positions.get(peer_id, player.position)
        _draw_tank(visual_player)
    _draw_aim()
    draw_rect(Rect2(402, 5, 476, 48), Color(0.04, 0.12, 0.18, 0.76))
    draw_rect(Rect2(225, 655, 830, 50), Color(0.04, 0.12, 0.18, 0.76))

func _draw_tank(player: Dictionary) -> void:
    var pos: Vector2 = player.position
    draw_circle(pos + Vector2(3, 5), 23.0, Color(0, 0, 0, 0.28))
    draw_set_transform(pos, float(player.aim), Vector2.ONE)
    var steel: bool = player.tank == "steel"
    var team_color := Color("65d8f4") if player.team == 0 else Color("ff8f78")
    var texture: Texture2D = STEEL_TEXTURE if steel else WING_TEXTURE
    draw_texture_rect(texture, Rect2(-48, -32, 96, 64), false)
    if steel and player.boost > 0.0:
        draw_arc(Vector2.ZERO, 35.0, 0.0, TAU, 36, Color("ff5151"), 4.0, true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if player.invulnerable > 0.0:
        draw_arc(pos, 29.0, 0.0, TAU, 32, Color("b4f9ff"), 2.0, true)
    if player.charge > 0.0:
        var dir := Vector2.RIGHT.rotated(player.charge_angle)
        draw_line(pos, pos + dir * Sim.BEAM_RANGE, Color(0.72, 0.95, 1.0, 0.55), 3.0, true)
    draw_rect(Rect2(pos + Vector2(-24, -38), Vector2(48, 6)), Color("172c36"))
    draw_rect(Rect2(pos + Vector2(-24, -38), Vector2(48 * maxf(0.0, player.hp / player.max_hp), 6)), Color("8ce89e"))
    draw_string(ThemeDB.fallback_font, pos + Vector2(-28, -46), str(player.name), HORIZONTAL_ALIGNMENT_CENTER, 56, 12, team_color)

func _draw_aim() -> void:
    if aim_mode.is_empty():
        return
    var p := _local_player()
    if p.is_empty() or p.dead > 0.0:
        return
    if not is_host:
        p = p.duplicate()
        p.position = visual_positions.get(local_id, p.position)
    var pointer := get_global_mouse_position()
    var color := Color("f8e692") if p.position.distance_to(pointer) <= Sim.CAST_RANGE else Color("ff6b73")
    if aim_mode == "missile" or p.tank == "steel":
        draw_arc(p.position, Sim.CAST_RANGE, 0.0, TAU, 100, Color(0.8, 1, 1, 0.55), 2.0, true)
        var radius := 20.0 if aim_mode == "missile" else 100.0
        draw_arc(pointer, radius, 0.0, TAU, 48, color, 3.0, true)
        if aim_mode == "missile":
            for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
                draw_line(pointer + direction * 12.0, pointer + direction * 27.0, color, 3.0, true)
            draw_circle(pointer, 2.5, color)
    else:
        var angle: float = p.position.angle_to_point(pointer)
        var dir := Vector2.RIGHT.rotated(angle)
        var normal := dir.orthogonal() * 32.0
        draw_colored_polygon(PackedVector2Array([p.position + normal, p.position - normal, p.position + dir*Sim.BEAM_RANGE - normal, p.position + dir*Sim.BEAM_RANGE + normal]), Color(0.55, 0.95, 1.0, 0.16))
        draw_line(p.position + normal, p.position + dir*Sim.BEAM_RANGE + normal, Color("9ff5ff"), 2.0)
        draw_line(p.position - normal, p.position + dir*Sim.BEAM_RANGE - normal, Color("9ff5ff"), 2.0)
