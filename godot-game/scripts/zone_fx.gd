extends RefCounted

# Pure 2D decorative effects: these functions never alter combat radii or hit tests.
const GHOST_RADIUS := 125.0
const VINE_RADIUS := 80.0

static func _poly(canvas: Node2D, points: PackedVector2Array, color: Color) -> void:
    canvas.draw_colored_polygon(points, color)

static func _triangle(canvas: Node2D, center: Vector2, radius: float, angle: float, color: Color, width: float) -> void:
    var points := PackedVector2Array()
    for i in range(3):
        points.append(center + Vector2.from_angle(angle + TAU * float(i) / 3.0) * radius)
    points.append(points[0])
    canvas.draw_polyline(points, color, width, true)

static func _flame(canvas: Node2D, foot: Vector2, size: float, phase: float, opacity: float) -> void:
    var sway := sin(phase) * size * .12
    var outer := PackedVector2Array([
        foot + Vector2(-size * .43, 0),
        foot + Vector2(-size * .53, -size * .39),
        foot + Vector2(-size * .20, -size * .79),
        foot + Vector2(sway, -size * 1.45),
        foot + Vector2(size * .29, -size * .82),
        foot + Vector2(size * .50, -size * .35),
        foot + Vector2(size * .37, 0)
    ])
    var core := PackedVector2Array([
        foot + Vector2(-size * .21, 0),
        foot + Vector2(-size * .24, -size * .32),
        foot + Vector2(sway * .5, -size * .88),
        foot + Vector2(size * .23, -size * .32),
        foot + Vector2(size * .17, 0)
    ])
    canvas.draw_circle(foot + Vector2(0, -size * .3), size * .8, Color(1, .26, .02, .085 * opacity))
    _poly(canvas, outer, Color(1, .28, .025, .7 * opacity))
    _poly(canvas, core, Color(1, .82, .23, .9 * opacity))
    canvas.draw_circle(foot + Vector2(0, -size * .15), size * .13, Color(1, .96, .7, .9 * opacity))

static func _candle(canvas: Node2D, point: Vector2, phase: float, alpha: float) -> void:
    # A small wax candle on a dark holder; all four remain upright on screen.
    canvas.draw_circle(point + Vector2(0, 2), 12, Color(1, .32, .05, .07 * alpha))
    canvas.draw_rect(Rect2(point + Vector2(-6, -4), Vector2(12, 5)), Color(.16, .08, .09, .8 * alpha))
    canvas.draw_rect(Rect2(point + Vector2(-4, -16), Vector2(8, 13)), Color(.84, .67, .40, .93 * alpha))
    canvas.draw_rect(Rect2(point + Vector2(-4, -16), Vector2(3, 13)), Color(1, .84, .59, .85 * alpha))
    canvas.draw_line(point + Vector2(0, -16), point + Vector2(0, -20), Color(.18, .1, .08, alpha), 1.5, true)
    _flame(canvas, point + Vector2(0, -20), 6.0, phase, alpha)

static func draw_ghost(canvas: Node2D, center: Vector2, life: float) -> void:
    var alpha := clampf(life / .25, 0.0, 1.0)
    var phase := float(Time.get_ticks_msec()) * .003
    # Broad low-opacity disks emulate an inner-to-outer glow without covering tanks.
    for i in range(7):
        var radius := GHOST_RADIUS * (1.0 - float(i) * .11)
        canvas.draw_circle(center, radius, Color(.80, .075 + i * .009, .014, (.032 + i * .002) * alpha))
    for ring in [[125.0, 6.0, .12], [122.0, 3.0, .30], [119.0, 1.8, .75], [110.0, 1.3, .56], [103.0, 1.2, .42], [68.0, 1.2, .52], [54.0, 1.0, .46], [16.0, 1.6, .7]]:
        canvas.draw_arc(center, ring[0], 0, TAU, 96, Color(1, .47 + .08 * sin(phase), .15, ring[2] * alpha), ring[1], true)
    _triangle(canvas, center, 106.0, -PI / 2.0, Color(1, .58, .24, .65 * alpha), 1.7)
    _triangle(canvas, center, 106.0, PI / 2.0, Color(1, .58, .24, .65 * alpha), 1.7)
    _triangle(canvas, center, 58.0, -PI / 2.0, Color(1, .72, .36, .65 * alpha), 1.3)
    _triangle(canvas, center, 58.0, PI / 2.0, Color(1, .44, .17, .58 * alpha), 1.3)
    # Fine rune marks on the outer ring and six sigils near the vertices.
    for i in range(48):
        var a := TAU * float(i) / 48.0 + .015 * sin(phase * .5)
        var radial := Vector2.from_angle(a)
        var tangent := radial.orthogonal()
        var base := center + radial * 114.5
        var r_len := 2.3 + float(i % 3)
        canvas.draw_line(base - radial * r_len, base + radial * r_len, Color(1, .75, .39, .72 * alpha), 1.1, true)
        canvas.draw_line(base + tangent * 2.2, base + radial * r_len * .65 - tangent * 1.7, Color(1, .61, .27, .52 * alpha), 1.0, true)
    for i in range(6):
        var angle := -PI / 2.0 + TAU * float(i) / 6.0
        var point := center + Vector2.from_angle(angle) * 74.0
        canvas.draw_circle(point, 6.0, Color(1, .32, .06, .18 * alpha))
        canvas.draw_arc(point, 5.0, 0, TAU, 20, Color(1, .80, .44, .83 * alpha), 1.2, true)
        canvas.draw_circle(point, 1.5, Color(1, .91, .58, alpha))
    canvas.draw_circle(center, 10.0, Color(1, .38, .09, .18 * alpha))
    canvas.draw_arc(center, 9.0, 0, TAU, 24, Color(1, .80, .46, .8 * alpha), 1.4, true)
    for i in range(4):
        var p := center + Vector2.from_angle(i * PI / 2.0) * 88.0
        _candle(canvas, p, phase * 2.0 + i, alpha)
    for i in range(12):
        var a := TAU * float(i) / 12.0
        var foot := center + Vector2.from_angle(a) * 123.0
        _flame(canvas, foot, 7.0 + 1.5 * sin(phase * 1.9 + i), phase * 2 + i * 1.3, alpha * .9)
    for i in range(10):
        var a := TAU * float(i) / 10.0 + phase * .08
        var offset := 84.0 + 25.0 * sin(phase + float(i) * 2.4)
        var spark := center + Vector2.from_angle(a) * offset + Vector2(0, -5.0 * fposmod(phase + i, 2.0))
        canvas.draw_circle(spark, 1.2 + (i % 2) * .5, Color(1, .69, .23, .65 * alpha))

static func _leaf(canvas: Node2D, base: Vector2, direction: Vector2, length: float, color: Color) -> void:
    var normal := direction.orthogonal()
    var tip := base + direction * length
    _poly(canvas, PackedVector2Array([base, base + direction * length * .42 + normal * length * .22, tip, base + direction * length * .42 - normal * length * .22]), color)
    canvas.draw_line(base, tip, Color(.66, .91, .38, color.a * .7), 1.0, true)

static func draw_vine(canvas: Node2D, center: Vector2, life: float) -> void:
    var fade := clampf(life / .25, 0.0, 1.0)
    var growth := clampf((2.0 - life) / .30, 0.0, 1.0)
    var radius := VINE_RADIUS * (.82 + .18 * growth)
    var phase := float(Time.get_ticks_msec()) * .002
    # Soft grass clearing with an edge that coincides with the gameplay radius.
    canvas.draw_circle(center, radius, Color(.10, .37, .10, .39 * fade))
    canvas.draw_circle(center, radius * .90, Color(.23, .56, .11, .22 * fade))
    canvas.draw_circle(center, radius * .68, Color(.44, .67, .16, .14 * fade))
    canvas.draw_arc(center, radius, 0, TAU, 64, Color(.50, .92, .33, .45 * fade), 2.0, true)
    canvas.draw_arc(center, radius * .94, 0, TAU, 64, Color(.75, 1.0, .49, .25 * fade), 1.0, true)
    for i in range(45):
        var a := float(i) * 2.39996
        var d := radius * sqrt((float(i) + .5) / 45.0) * .94
        var p := center + Vector2.from_angle(a) * d
        var h := (4.0 + float(i % 4) * 1.4) * growth
        var sway := sin(phase * 1.6 + i) * 1.1
        canvas.draw_line(p, p + Vector2(-2.5 + sway, -h), Color(.24, .62, .17, .58 * fade), 1.5, true)
        canvas.draw_line(p, p + Vector2(2.0 + sway, -h * .75), Color(.57, .81, .29, .55 * fade), 1.2, true)
    for i in range(10):
        var angle := float(i) * TAU / 10.0 + .06 * sin(phase + i)
        var direction := Vector2.from_angle(angle)
        var normal := direction.orthogonal()
        var start := center + direction * 10.0
        var end := center + direction * (radius * .84 * growth)
        var points := PackedVector2Array([start, start + direction * 20 + normal * 5, start + direction * 39 - normal * 4, end])
        canvas.draw_polyline(points, Color(.07, .36, .12, .7 * fade), 4.0, true)
        canvas.draw_polyline(points, Color(.45, .78, .24, .72 * fade), 1.4, true)
        var leaf_pos := start + direction * (32.0 * growth) + normal * 2.0
        _leaf(canvas, leaf_pos, (direction + normal * (.65 if i % 2 == 0 else -.65)).normalized(), 11.0 * growth, Color(.34, .73, .18, .7 * fade))

static func draw_vines(canvas: Node2D, pos: Vector2) -> void:
    # Drawn after the tank so bindings remain visible over the artwork.
    for i in range(4):
        var y := -22.0 + float(i) * 14.0
        var points := PackedVector2Array([pos + Vector2(-27, y + 5), pos + Vector2(-18, y - 3), pos + Vector2(-8, y + 2), pos + Vector2(1, y - 5), pos + Vector2(12, y + 1), pos + Vector2(24, y - 5)])
        canvas.draw_polyline(points, Color("214d24"), 6.0, true)
        canvas.draw_polyline(points, Color("4eab39"), 4.0, true)
        canvas.draw_polyline(points, Color("b5ed72"), 1.1, true)
        _leaf(canvas, pos + Vector2(-14 + (i % 2) * 18, y), Vector2(.7, -1).normalized(), 8.0, Color("6dc838"))
        _leaf(canvas, pos + Vector2(7 - (i % 2) * 12, y), Vector2(.6, 1).normalized(), 7.0, Color("65b736"))
