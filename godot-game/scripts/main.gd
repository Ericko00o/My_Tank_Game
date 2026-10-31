extends Node2D

const Sim = preload("res://scripts/simulation.gd")
const Minimap = preload("res://scripts/minimap.gd")
const STEEL_TEXTURE = preload("res://assets/steel.png")
const WING_TEXTURE = preload("res://assets/wing.png")
const ICE_FLOOR = preload("res://assets/ice_floor.png")
const JUNGLE_FLOOR = preload("res://assets/jungle_floor.png")
const ICE_BLOCK = preload("res://assets/ice_block.svg")
const MISSILE_TEXTURE = preload("res://assets/missile.svg")
const PORT := 23456
const MAX_PLAYERS := 4
const SEND_INTERVAL := 0.05
const TANK_IDS := ["steel", "wing", "ghost", "dark", "elf"]
const TANK_NAMES := {"steel": "鋼鐵", "wing": "飛翼", "ghost": "惡靈", "dark": "黑暗騎士", "elf": "精靈王子"}
const SPRITE_PATHS := {"steel": "res://assets/tank_steel.png", "wing": "res://assets/tank_wing.png", "ghost": "res://assets/tank_ghost.png", "dark": "res://assets/tank_dark.png", "elf": "res://assets/tank_elf.png"}

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
var predicted_hull_angle := 0.0
var predicted_hull_ready := false
var mouse_down := false
var selected_tank := "steel"
var selected_map := "ice"
var camera: Camera2D
var minimap: Control
var tank_sprites: Dictionary = {}
var hud_background: ColorRect
var instruction_background: ColorRect

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
    camera = Camera2D.new()
    camera.enabled = false
    add_child(camera)
    for kind in TANK_IDS:
        if ResourceLoader.exists(SPRITE_PATHS[kind]):
            tank_sprites[kind] = load(SPRITE_PATHS[kind])
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
    hud_background = ColorRect.new()
    hud_background.position = Vector2(402, 5)
    hud_background.size = Vector2(476, 48)
    hud_background.color = Color(0.04, 0.12, 0.18, 0.76)
    hud_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(hud_background)
    hud_background.hide()
    instruction_background = ColorRect.new()
    instruction_background.position = Vector2(225, 655)
    instruction_background.size = Vector2(830, 50)
    instruction_background.color = Color(0.04, 0.12, 0.18, 0.76)
    instruction_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(instruction_background)
    instruction_background.hide()
    minimap = Minimap.new()
    minimap.position = Vector2(18, 18)
    minimap.size = Vector2(224, 126)
    ui.add_child(minimap)
    minimap.hide()
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
    tank_choice.add_item("惡靈 · 烈焰審判", 2)
    tank_choice.add_item("黑暗騎士 · 蝙蝠飛鏢", 3)
    tank_choice.add_item("精靈王子 · 藤蔓纏繞", 4)
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
    return TANK_IDS[clampi(tank_choice.selected, 0, TANK_IDS.size() - 1)]

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
    var safe_tank := tank if tank in TANK_IDS else "steel"
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
        var tank_name: String = TANK_NAMES.get(entry.tank, "鋼鐵")
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
    predicted_hull_ready = false
    sim.map_id = map_id
    sim.walls = Sim.wall_rects(map_id)
    aim_mode = ""
    mouse_down = false
    panel.hide()
    hud.show()
    instruction.show()
    exit_button.show()
    hud_background.show()
    instruction_background.show()
    minimap.show()
    camera.enabled = true
    if is_host:
        sim.setup(data, map_id)
        if practice and sim.players.has(-1):
            sim.players[-1].position = sim.players[1].position + Vector2(600, 0)
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
    predicted_hull_ready = false
    panel.show()
    hud.hide()
    instruction.hide()
    exit_button.hide()
    hud_background.hide()
    instruction_background.hide()
    minimap.hide()
    camera.enabled = false
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
    _update_camera_and_models()
    _update_hud()
    queue_redraw()

func _update_camera_and_models() -> void:
    var local := _local_player()
    if not local.is_empty():
        var center: Vector2 = visual_positions.get(local_id, local.position) if not is_host else local.position
        camera.position = Vector2(clampf(center.x, 640.0, Sim.WORLD.x - 640.0), clampf(center.y, 360.0, Sim.WORLD.y - 360.0))
    minimap.state = view_state
    minimap.local_id = local_id
    minimap.camera_center = camera.position
    minimap.queue_redraw()

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
        if not predicted_hull_ready or player.dead > 0.0:
            predicted_hull_angle = float(player.get("hull_angle", 0.0))
            predicted_hull_ready = true
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
    if p.dead <= 0.0 and p.charge <= 0.0 and float(p.get("ghost_root", 0.0)) <= 0.0 and float(p.get("vine_root", 0.0)) <= 0.0 and float(p.get("ghost_channel", 0.0)) <= 0.0 and p.get("pull", {}).is_empty():
        var input := _gather_input()
        if input.direction.length_squared() > 0.0001:
            predicted_hull_angle = input.direction.angle()
            predicted_hull_ready = true
        var speed: float = 270.0 if p.boost > 0.0 else Sim.base_speed(p.tank)
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
            if _can_cast(player) and player.e_cd <= 0.0:
                match player.tank:
                    "steel": _send_ability("boost", Vector2.ZERO)
                    "dark": _send_ability("dark_stealth", Vector2.ZERO)
                    "wing": _toggle_aim("missile")
                    "ghost": _toggle_aim("ghost_hook")
                    "elf": _toggle_aim("elf_arrow")
        elif key.keycode == KEY_SPACE:
            var player := _local_player()
            if _can_cast(player) and player.ult_cd <= 0.0:
                match player.tank:
                    "ghost": _send_ability("ghost_ult", Vector2.ZERO)
                    "dark": _toggle_aim("dark_ult")
                    "elf": _toggle_aim("elf_ult")
                    _: _toggle_aim("ultimate")
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

func _can_cast(player: Dictionary) -> bool:
    return not player.is_empty() and player.dead <= 0.0 and player.charge <= 0.0 and float(player.get("ghost_root", 0.0)) <= 0.0 and float(player.get("vine_root", 0.0)) <= 0.0 and float(player.get("ghost_channel", 0.0)) <= 0.0

func _toggle_aim(mode: String) -> void:
    aim_mode = "" if aim_mode == mode else mode

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
    for y in range(2):
        for x in range(2):
            draw_texture_rect(floor_texture, Rect2(Vector2(x * Sim.TILE_SIZE.x, y * Sim.TILE_SIZE.y), Sim.TILE_SIZE), false)
    draw_rect(Rect2(Vector2.ZERO, Sim.WORLD), Color(0.04, 0.10, 0.12, 0.16))
    for i in range(360):
        var point := Vector2((i * 191 + 13) % int(Sim.WORLD.x), (i * 137 + 49) % int(Sim.WORLD.y))
        var color := Color(0.55, 0.76, 0.4, 0.20) if jungle else Color(0.8, 0.95, 1.0, 0.26)
        draw_circle(point, 2.0 + i % 3, color)
    for obstacle: Rect2 in Sim.wall_rects(map_id):
        draw_rect(Rect2(obstacle.position + Vector2(5, 8), obstacle.size), Color(0.05, 0.11, 0.15, 0.32))
        var side_color := Color("58715a") if jungle else Color("5b9bb8")
        var top_color := Color("aab393") if jungle else Color("d2eef1")
        draw_rect(obstacle, side_color)
        draw_rect(Rect2(obstacle.position, obstacle.size - Vector2(0, 8)), top_color)
        draw_rect(Rect2(obstacle.position + Vector2(3, 3), obstacle.size - Vector2(6, 14)), Color(1, 1, 1, .22), false, 2.0)
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
            _draw_bombardment(center, 3.0 - float(field.life))
        elif field.kind == "ghost_zone":
            _draw_ghost_zone(field.position, float(field.life))
        elif field.kind == "vine_zone":
            _draw_vine_zone(field.position, float(field.life))
    for bullet in view_state.get("bullets", []):
        var position: Vector2 = bullet.position
        var direction: Vector2 = bullet.velocity.normalized()
        match str(bullet.kind):
            "missile": _draw_missile(position, direction)
            "ghost_shot", "ghost_hook":
                if bullet.kind == "ghost_hook" and view_state.players.has(bullet.owner):
                    var owner_pos: Vector2 = view_state.players[bullet.owner].position
                    var start: Vector2 = owner_pos + (position - owner_pos).normalized() * Sim.muzzle_offset("ghost")
                    draw_line(start, position, Color("8c8e91"), 4.0, true)
                    draw_line(start, position, Color("f47f42"), 1.5, true)
                _draw_hook(position, direction, bullet.kind == "ghost_hook")
            "dark_shot": _draw_bat(position, direction.angle(), 10.0, Color("aa71ea"))
            "elf_shot", "elf_arrow", "elf_ult": _draw_arrow(position, direction, str(bullet.kind))
            _:
                var owner: Dictionary = view_state.players.get(bullet.owner, {})
                var tint := Color("ffe174") if bullet.pierce else (Color("ff6c6c") if owner.get("tank", "steel") == "steel" else Color("e5fbff"))
                if owner.get("tank", "steel") == "wing" and not bullet.pierce:
                    _draw_shell(position, direction)
                else:
                    draw_line(position - direction * (35.0 if bullet.pierce else 15.0), position + direction * 7.0, tint, 6.0 if bullet.pierce else 4.0, true)
    for effect in view_state.get("effects", []):
        var position: Vector2 = effect.position
        if effect.kind == "laser":
            _draw_laser(position, effect)
        elif effect.kind == "explosion":
            draw_circle(position, 30.0 * float(effect.life) / 0.5, Color(1, .5, .15, .7))
        elif effect.kind == "hit":
            draw_arc(position, 25.0, 0.0, TAU, 20, Color("fff3b2"), 3.0, true)
        elif effect.kind == "ice_hit":
            draw_arc(position, 24.0, 0.0, TAU, 20, Color("c3faff"), 3.0, true)
        elif effect.kind == "ghost_blast":
            var fade := clampf(float(effect.life) / .5, 0.0, 1.0)
            draw_circle(position, 125.0 * (1.0 - fade * .4), Color(1.0, .22, .04, .2 * fade))
            draw_arc(position, 125.0 * (1.0 - fade * .4), 0, TAU, 48, Color(1.0, .55, .15, fade), 5, true)
        elif effect.kind == "bat_ult":
            _draw_bat_ultimate(position, float(effect.angle), float(effect.life))
    for peer_id in view_state.players:
        var player: Dictionary = view_state.players[peer_id]
        if player.dead > 0.0:
            continue
        if _is_hidden_enemy(player):
            continue
        var visual_player := player.duplicate()
        if not is_host:
            visual_player.position = visual_positions.get(peer_id, player.position)
        _draw_tank(visual_player)
    _draw_aim()

func _is_hidden_enemy(player: Dictionary) -> bool:
    var local := _local_player()
    return float(player.get("invisible", 0.0)) > 0.0 and not local.is_empty() and player.team != local.team

func _draw_tank(player: Dictionary) -> void:
    var pos: Vector2 = player.position
    var steel: bool = player.tank == "steel"
    var team_color := Color("65d8f4") if player.team == 0 else Color("ff8f78")
    var invisible := float(player.get("invisible", 0.0)) > 0.0
    var opacity := 0.42 if invisible else 1.0
    var angles := _player_angles(player)
    draw_circle(pos + Vector2(4, 9), 25.0, Color(0, 0, 0, 0.22 * opacity))
    # Tracks and turret are drawn separately so movement and aim remain independent.
    draw_set_transform(pos, angles.hull, Vector2.ONE)
    for side in [-1, 1]:
        draw_rect(Rect2(-27, side * 21 - 7, 54, 14), Color(.08, .12, .16, opacity))
        draw_rect(Rect2(-24, side * 21 - 4, 48, 8), Color(.28, .36, .40, opacity))
        for x in range(-20, 25, 10):
            draw_line(Vector2(x, side * 21 - 6), Vector2(x, side * 21 + 6), Color(.55, .63, .65, opacity), 2.0)
    draw_circle(Vector2.ZERO, 18.0, Color(.13, .19, .22, opacity))
    draw_set_transform(pos, angles.turret, Vector2.ONE)
    var texture: Texture2D = tank_sprites.get(player.tank, STEEL_TEXTURE if steel else WING_TEXTURE)
    # Artwork faces right; Sim.muzzle_offset stores each silhouette's tip.
    draw_texture_rect(texture, Rect2(-50, -43, 100, 86), false, Color(1, 1, 1, opacity))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if steel and player.boost > 0.0:
        draw_arc(pos, 35.0, 0.0, TAU, 36, Color("ff5151"), 4.0, true)
    if player.invulnerable > 0.0:
        draw_arc(pos, 29.0, 0.0, TAU, 32, Color("b4f9ff"), 2.0, true)
    if player.charge > 0.0:
        var dir := Vector2.RIGHT.rotated(player.charge_angle)
        draw_line(pos, pos + dir * Sim.BEAM_RANGE, Color(0.72, 0.95, 1.0, 0.35), 2.0, true)
        _draw_charge_orb(pos + dir * Sim.muzzle_offset(player.tank), clampf(1.0 - float(player.charge), 0.0, 1.0))
    if float(player.get("ghost_root", 0.0)) > 0.0:
        draw_arc(pos, 34.0, 0.0, TAU, 32, Color("ff8140"), 4.0, true)
        for i in range(4):
            var a := float(i) * PI / 2.0
            draw_line(pos + Vector2.from_angle(a) * 22.0, pos + Vector2.from_angle(a + .5) * 32.0, Color("ffc15a"), 3.0, true)
    if float(player.get("vine_root", 0.0)) > 0.0:
        _draw_vines(pos)
    if float(player.get("poison_normal", 0.0)) > 0.0 or float(player.get("poison_ultimate", 0.0)) > 0.0:
        draw_circle(pos, 27.0, Color(.52, .10, .75, .27))
        _draw_bat(pos + Vector2(0, -48), 0.0, 7.0, Color("c58fff"))
    if not player.get("marks", {}).is_empty():
        draw_arc(pos, 34.0, 0.0, TAU, 24, Color("e6e8a1"), 2.0, true)
    draw_rect(Rect2(pos + Vector2(-27, -53), Vector2(54, 6)), Color("172c36"))
    draw_rect(Rect2(pos + Vector2(-27, -53), Vector2(54 * maxf(0.0, player.hp / player.max_hp), 6)), Color("8ce89e"))
    draw_string(ThemeDB.fallback_font, pos + Vector2(-32, -61), str(player.name), HORIZONTAL_ALIGNMENT_CENTER, 64, 12, team_color)

func _player_angles(player: Dictionary) -> Dictionary:
    var hull := float(player.get("hull_angle", 0.0))
    var turret := float(player.aim)
    if player.id == local_id and not is_host:
        if predicted_hull_ready:
            hull = predicted_hull_angle
        if player.dead <= 0.0 and player.charge <= 0.0 and float(player.get("ghost_channel", 0.0)) <= 0.0:
            turret = float(_gather_input().angle)
    return {"hull": hull, "turret": turret}

func _draw_missile(pos: Vector2, direction: Vector2) -> void:
    var tail := pos - direction * 13.0
    draw_line(tail - direction * 17.0, tail, Color(1.0, 0.29, 0.06, 0.30), 10.0, true)
    draw_line(tail - direction * 13.0, tail, Color("ffba58"), 5.0, true)
    draw_line(tail - direction * 8.0, tail, Color("fff9c4"), 2.0, true)
    draw_set_transform(pos, direction.angle(), Vector2.ONE)
    draw_texture_rect(MISSILE_TEXTURE, Rect2(-17, -8, 34, 16), false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shell(pos: Vector2, direction: Vector2) -> void:
    var n := direction.orthogonal()
    draw_line(pos - direction * 24, pos - direction * 6, Color(.5, .85, 1, .3), 5, true)
    draw_colored_polygon(PackedVector2Array([pos + direction * 11, pos + direction * 3 + n * 4, pos - direction * 10 + n * 4, pos - direction * 10 - n * 4, pos + direction * 3 - n * 4]), Color("b6cfdb"))
    draw_line(pos - direction * 6, pos + direction * 5, Color.WHITE, 2.0, true)

func _draw_hook(pos: Vector2, direction: Vector2, heavy: bool) -> void:
    var normal := direction.orthogonal()
    var width := 3.0 if heavy else 2.0
    var reach := 13.0 if heavy else 8.0
    draw_line(pos - direction * 18, pos, Color("fa6625"), width * 2.5, true)
    draw_line(pos - direction * 14, pos, Color("ffd076"), width, true)
    draw_line(pos - direction * 5, pos + direction * reach, Color("d1d4d3"), width, true)
    draw_line(pos + direction * reach, pos + direction * (reach - 4) + normal * 7, Color("f4f3e9"), width, true)
    draw_line(pos + direction * (reach - 4) + normal * 7, pos + direction * (reach - 9) + normal * 5, Color("c7ced0"), width, true)

func _draw_bat(pos: Vector2, angle: float, size: float, color: Color) -> void:
    draw_set_transform(pos, angle, Vector2.ONE * (size / 10.0))
    for side in [-1, 1]:
        draw_colored_polygon(PackedVector2Array([Vector2(2, side), Vector2(-1, side * 5), Vector2(-9, side * 13), Vector2(-7, side * 6), Vector2(-12, side * 3), Vector2(-6, side * 2), Vector2(-3, 0)]), color)
    draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(3, -4), Vector2(-5, -3), Vector2(-8, 0), Vector2(-5, 3), Vector2(3, 4)]), color)
    draw_circle(Vector2(4, 0), 2.0, Color("efe6ff"))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_arrow(pos: Vector2, direction: Vector2, kind: String) -> void:
    var long_arrow := kind != "elf_shot"
    var n := direction.orthogonal()
    var length := 34.0 if long_arrow else 22.0
    var color := Color("a6ef80") if kind == "elf_ult" else Color("f6e1a0")
    draw_line(pos - direction * length, pos + direction * 6, color, 4.0 if long_arrow else 2.0, true)
    draw_colored_polygon(PackedVector2Array([pos + direction * 10, pos - direction * 2 + n * 6, pos + direction * 1, pos - direction * 2 - n * 6]), Color("e8fff0") if kind == "elf_ult" else Color("f6f7ed"))
    draw_line(pos - direction * length, pos - direction * (length - 8) + n * 5, Color("e8fff5"), 2.0)
    draw_line(pos - direction * length, pos - direction * (length - 8) - n * 5, Color("e8fff5"), 2.0)

func _draw_ghost_zone(center: Vector2, life: float) -> void:
    var radius := 125.0
    draw_circle(center, radius, Color(.82, .12, .03, .19))
    draw_arc(center, radius, 0, TAU, 64, Color("ff8d36"), 4.0, true)
    draw_arc(center, radius * .8, 0, TAU, 64, Color("ffd26b"), 2.0, true)
    for offset in [0.0, PI]:
        var points := PackedVector2Array()
        for i in range(4):
            points.append(center + Vector2.from_angle(offset + float(i % 3) * TAU / 3.0 - PI / 2.0) * radius * .72)
        draw_polyline(points, Color("ffbb54"), 3.0, true)
    for i in range(8):
        var angle := float(i) * TAU / 8.0 + life * .5
        var start := center + Vector2.from_angle(angle) * 96.0
        draw_line(start, start + Vector2(0, -10 - 5 * sin(life * 8 + i)), Color("ff6a25"), 4.0, true)

func _draw_vine_zone(center: Vector2, _life: float) -> void:
    draw_circle(center, 78.0, Color(.21, .67, .21, .14))
    draw_arc(center, 78.0, 0, TAU, 48, Color("a4e86b"), 2.0, true)
    for i in range(8):
        var angle := float(i) * TAU / 8.0
        var start := center + Vector2.from_angle(angle) * 20
        var end := center + Vector2.from_angle(angle + .2) * 70
        draw_line(start, end, Color("469f51"), 4.0, true)

func _draw_vines(pos: Vector2) -> void:
    for i in range(3):
        var y := -17.0 + i * 15.0
        var points := PackedVector2Array([pos + Vector2(-25, y), pos + Vector2(-12, y - 5), pos + Vector2(0, y + 3), pos + Vector2(13, y - 4), pos + Vector2(25, y + 2)])
        draw_polyline(points, Color("3a9d4d"), 4.0, true)
        draw_polyline(points, Color("a3e678"), 1.5, true)

func _draw_bat_ultimate(pos: Vector2, angle: float, life: float) -> void:
    var progress := clampf(1.0 - life / .6, 0.0, 1.0)
    for i in range(12):
        var spread := lerpf(-.5, .5, float(i) / 11.0)
        var distance := (65.0 + float(i % 4) * 40.0) * (0.4 + .6 * progress)
        var direction := Vector2.from_angle(angle + spread)
        _draw_bat(pos + direction * distance, angle + spread, 19.0, Color("b47ce9"))

func _draw_charge_orb(pos: Vector2, progress: float) -> void:
    var radius := 6.0 + progress * 16.0
    draw_circle(pos, radius * 1.75, Color(0.08, 0.55, 1.0, 0.12))
    draw_circle(pos, radius * 1.3, Color(0.08, 0.7, 1.0, 0.22))
    draw_circle(pos, radius, Color(0.22, 0.78, 1.0, 0.65))
    draw_circle(pos, radius * 0.65, Color(0.65, 0.95, 1.0, 0.9))
    draw_circle(pos, radius * 0.3, Color.WHITE)
    draw_arc(pos, radius * 1.14, 0.0, TAU, 32, Color(0.65, 0.95, 1.0, 0.7), 2.0, true)

func _draw_laser(origin: Vector2, effect: Dictionary) -> void:
    var dir := Vector2.RIGHT.rotated(float(effect.angle))
    var length := float(effect.length)
    var start := origin + dir * minf(Sim.muzzle_offset("wing"), length * 0.4)
    var end := origin + dir * length
    var fade := clampf(float(effect.life) / 0.12, 0.0, 1.0)
    draw_line(start, end, Color(0.04, 0.43, 1.0, 0.17 * fade), 82.0, true)
    draw_line(start, end, Color(0.05, 0.59, 1.0, 0.30 * fade), 66.0, true)
    draw_line(start, end, Color(0.12, 0.76, 1.0, 0.55 * fade), 48.0, true)
    draw_line(start, end, Color(0.50, 0.93, 1.0, 0.85 * fade), 31.0, true)
    draw_line(start, end, Color(0.88, 1.0, 1.0, fade), 17.0, true)
    draw_line(start, end, Color(1.0, 1.0, 1.0, fade), 7.0, true)
    _draw_charge_orb(start, 1.0)

func _draw_bombardment(center: Vector2, elapsed: float) -> void:
    draw_circle(center, 100.0, Color(1.0, 0.25, 0.04, 0.13))
    draw_arc(center, 100.0, 0.0, TAU, 64, Color("ffd27b"), 3.0, true)
    # Deterministic local animation, derived from the server field lifetime.
    for i in range(7):
        var phase := fposmod(elapsed / 0.78 + float(i) * 0.173, 1.0)
        var impact := center + Vector2.from_angle(float(i) * 2.399) * (26.0 + float(i % 3) * 26.0)
        if phase < 0.58:
            var progress := phase / 0.58
            var missile_pos := impact + Vector2(-32, -115) * (1.0 - progress)
            var direction := Vector2(32, 115).normalized()
            draw_line(missile_pos - direction * 24.0, missile_pos, Color(1.0, 0.48, 0.13, 0.42), 7.0, true)
            _draw_missile(missile_pos, direction)
        else:
            var blast := (phase - 0.58) / 0.42
            var size := 8.0 + 21.0 * blast
            var alpha := 1.0 - blast
            draw_circle(impact, size * 1.5, Color(1.0, 0.25, 0.04, 0.19 * alpha))
            draw_circle(impact, size, Color(1.0, 0.42, 0.06, 0.65 * alpha))
            draw_circle(impact, size * 0.58, Color(1.0, 0.86, 0.35, 0.8 * alpha))
            draw_arc(impact, size * 1.25, 0.0, TAU, 24, Color(1.0, 0.79, 0.35, 0.7 * alpha), 2.0, true)

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
    if aim_mode == "missile" or (aim_mode == "ultimate" and p.tank == "steel"):
        draw_arc(p.position, Sim.CAST_RANGE, 0.0, TAU, 100, Color(0.8, 1, 1, 0.55), 2.0, true)
        var radius := 20.0 if aim_mode == "missile" else 100.0
        draw_arc(pointer, radius, 0.0, TAU, 48, color, 3.0, true)
        if aim_mode == "missile":
            for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
                draw_line(pointer + direction * 12.0, pointer + direction * 27.0, color, 3.0, true)
            draw_circle(pointer, 2.5, color)
    elif aim_mode == "dark_ult":
        var angle: float = p.position.angle_to_point(pointer)
        var polygon := PackedVector2Array([p.position])
        for i in range(25):
            polygon.append(p.position + Vector2.from_angle(angle - Sim.DARK_ULT_HALF_ANGLE + 2.0 * Sim.DARK_ULT_HALF_ANGLE * i / 24.0) * Sim.DARK_ULT_RANGE)
        draw_colored_polygon(polygon, Color(.56, .25, .82, .20))
        draw_arc(p.position, Sim.DARK_ULT_RANGE, angle - Sim.DARK_ULT_HALF_ANGLE, angle + Sim.DARK_ULT_HALF_ANGLE, 32, Color("d6aaff"), 2.0, true)
        draw_line(p.position, polygon[1], Color("d6aaff"), 2.0)
        draw_line(p.position, polygon[polygon.size() - 1], Color("d6aaff"), 2.0)
    else:
        var angle: float = p.position.angle_to_point(pointer)
        var dir := Vector2.RIGHT.rotated(angle)
        var length: float = Sim.BEAM_RANGE
        var tint := Color("9ff5ff")
        match aim_mode:
            "ghost_hook":
                length = Sim.GHOST_HOOK_RANGE
                tint = Color("ff9d62")
            "elf_arrow":
                length = Sim.ELF_ARROW_RANGE
                tint = Color("c4ef94")
            "elf_ult":
                length = Sim.ELF_ULT_RANGE
                tint = Color("c4ef94")
        var normal := dir.orthogonal() * (32.0 if aim_mode == "ultimate" else 22.0)
        var fill := Color(tint, .16)
        draw_colored_polygon(PackedVector2Array([p.position + normal, p.position - normal, p.position + dir * length - normal, p.position + dir * length + normal]), fill)
        draw_line(p.position + normal, p.position + dir * length + normal, tint, 2.0)
        draw_line(p.position - normal, p.position + dir * length - normal, tint, 2.0)
