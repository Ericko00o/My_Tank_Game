extends RefCounted

# All geometry is local to the projectile and faces +X, so it follows the
# authoritative trajectory without changing any of the game's hitboxes.
static func draw_arrow(canvas: Node2D, pos: Vector2, direction: Vector2, kind: String) -> void:
    var scale_factor := 1.0 if kind == "elf_shot" else (2.0 if kind == "elf_arrow" else 2.65)
    var is_ultimate := kind == "elf_ult"
    var is_skill := kind != "elf_shot"
    var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
    var gold := Color("f3c44c") if is_skill else Color("d9d8c6")
    var shine := Color("fff5ad") if is_skill else Color("fcfffb")
    # Delicate, short trails keep the arrow itself and the battlefield legible.
    canvas.draw_line(pos - dir * (17.0 * scale_factor), pos - dir * (7.0 * scale_factor), Color(.96, .81, .37, .13 if is_skill else .09), 5.0 * scale_factor, true)
    canvas.draw_set_transform(pos, dir.angle(), Vector2.ONE * scale_factor)
    canvas.draw_line(Vector2(-14, 1), Vector2(5, 1), Color("7f5b26") if is_skill else Color("8d806a"), 2.8, true)
    canvas.draw_line(Vector2(-14, 0), Vector2(5, 0), gold, 1.7, true)
    canvas.draw_line(Vector2(-12, -.7), Vector2(5, -.7), shine, .65, true)
    # Feather fletching is split in layers rather than just two thin lines.
    for side in [-1, 1]:
        canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-16, side * 4), Vector2(-9, side * 2.7), Vector2(-6, 0)]), Color("e9efe4"))
        canvas.draw_line(Vector2(-14, side * 3), Vector2(-8, side * .3), shine, .7, true)
    # The gold spearhead is visibly separate from its central ridge.
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(2, -4.5), Vector2(4.6, 0), Vector2(2, 4.5)]), gold)
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(2, -4.5), Vector2(4.6, 0)]), shine)
    canvas.draw_line(Vector2(4, 0), Vector2(11, 0), Color("fffde1"), .65, true)
    if is_ultimate:
        # A recognisable vine spirals around the shaft with leaves on both sides.
        var vine := PackedVector2Array([Vector2(-11, -1), Vector2(-8, 1.8), Vector2(-5, 2.0), Vector2(-2, -1.7), Vector2(1, -1.8), Vector2(4, 1.0)])
        canvas.draw_polyline(vine, Color("276b37"), 2.0, true)
        canvas.draw_polyline(vine, Color("80d76b"), .8, true)
        canvas.draw_colored_polygon(PackedVector2Array([Vector2(-7, 2), Vector2(-9, 4.5), Vector2(-5, 3.4)]), Color("74c952"))
        canvas.draw_colored_polygon(PackedVector2Array([Vector2(-1, -1.8), Vector2(0, -4.4), Vector2(2, -2)]), Color("a6eb75"))
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_bat(canvas: Node2D, pos: Vector2, angle: float, size: float, color: Color) -> void:
    var alpha := color.a
    # The same silhouette is used for violet poison markers and black ultimate
    # darts; keep the caller's tint instead of forcing every bat to black.
    var dark := color.darkened(.22)
    dark.a = alpha
    var edge := color.lerp(Color(.78, .79, .85, alpha), .48)
    edge.a = .90 * alpha
    var facet := color.lerp(Color(.55, .56, .61, alpha), .28)
    var soft_highlight := color.lerp(Color(.90, .92, .98, alpha), .60)
    soft_highlight.a = .80 * alpha
    canvas.draw_set_transform(pos, angle, Vector2.ONE * (size / 10.0))
    for side in [-1, 1]:
        # The long pointed wing tip and two scalloped curves read as a bat in
        # flight, not the straight fins of a conventional arrow or aircraft.
        var wing := PackedVector2Array([Vector2(5, side), Vector2(4, side * 3), Vector2(3.5, side * 6), Vector2(4, side * 9), Vector2(7, side * 12), Vector2(7, side * 23), Vector2(5, side * 20), Vector2(1, side * 18), Vector2(-4, side * 16), Vector2(-3, side * 14), Vector2(-3, side * 11), Vector2(-4, side * 8), Vector2(-6, side * 5), Vector2(-10, 0)])
        canvas.draw_colored_polygon(wing, dark)
        canvas.draw_polyline(wing + PackedVector2Array([wing[0]]), edge, .9, true)
        canvas.draw_colored_polygon(PackedVector2Array([Vector2(4, side * 3), Vector2(6, side * 20), Vector2(1, side * 16), Vector2(-2, side * 12), Vector2(-1, side * 7)]), facet)
        canvas.draw_line(Vector2(5, side * 4), Vector2(6, side * 20), soft_highlight, .65, true)
        canvas.draw_polyline(PackedVector2Array([Vector2(-7, side * 2), Vector2(-4, side * 7), Vector2(-3, side * 11), Vector2(-3, side * 14), Vector2(-4, side * 16)]), edge, .7, true)
    var body := PackedVector2Array([Vector2(8, 0), Vector2(5, -1.2), Vector2(8, -3), Vector2(4, -3), Vector2(3, -4), Vector2(-2, -3), Vector2(-6, -2), Vector2(-12, 0), Vector2(-6, 2), Vector2(-2, 3), Vector2(3, 4), Vector2(4, 3), Vector2(8, 3), Vector2(5, 1.2)])
    canvas.draw_colored_polygon(body, dark)
    canvas.draw_polyline(body + PackedVector2Array([body[0]]), edge, .9, true)
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(2, -2), Vector2(-8, 0)]), facet)
    canvas.draw_line(Vector2(-8, 0), Vector2(6, 0), soft_highlight, .65, true)
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_bat_ultimate(canvas: Node2D, origin: Vector2, angle: float, life: float) -> void:
    var progress := clampf(1.0 - life / .6, 0.0, 1.0)
    var fade := clampf(life / .12, 0.0, 1.0)
    var start := origin + Vector2.from_angle(angle) * 47.0
    # Multiple overlapping, solid black darts travel through the same fan.
    for i in range(18):
        var lane := i % 9
        var spread := lerpf(-.50, .50, float(lane) / 8.0)
        var direction := Vector2.from_angle(angle + spread)
        var offset := float(i / 9) * .16 + float(lane % 3) * .045
        var travel := clampf(progress * 1.15 - offset, 0.0, 1.0)
        var position := start + direction * (15.0 + travel * 205.0)
        canvas.draw_line(position - direction * 14.0, position + direction * 3.0, Color(.38, .33, .48, .18 * fade), 3.0, true)
        draw_bat(canvas, position, direction.angle(), 18.0, Color(.045, .047, .065, fade))

static func draw_missile(canvas: Node2D, pos: Vector2, direction: Vector2, texture: Texture2D) -> void:
    var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
    var flicker := .8 + .2 * sin(float(Time.get_ticks_msec()) * .035)
    canvas.draw_set_transform(pos, dir.angle(), Vector2.ONE)
    # Tiny layered fire attached to the engine, plus a translucent exhaust wake.
    canvas.draw_line(Vector2(-35, 0), Vector2(-13, 0), Color(1.0, .33, .05, .18), 10.0, true)
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, -4), Vector2(-24 - 5 * flicker, 0), Vector2(-13, 4)]), Color(1.0, .28, .03, .85))
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(-14, -2.7), Vector2(-23 - 3 * flicker, 0), Vector2(-14, 2.7)]), Color("ffb43d"))
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(-14, -1.5), Vector2(-20 - 2 * flicker, 0), Vector2(-14, 1.5)]), Color("fff6bd"))
    if texture != null:
        canvas.draw_texture_rect(texture, Rect2(-17, -8, 34, 16), false)
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
