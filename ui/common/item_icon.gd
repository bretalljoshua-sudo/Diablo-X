class_name ItemIcon
extends RefCounted
## Zeichnet einen Gegenstand in ein Rechteck: Hintergrund und Rahmen nach Seltenheit,
## darauf ItemBase.icon oder, solange AP8 keine Symbole liefert, ein einfaches Zeichen je Platz.


## Zeichnet item auf canvas in rect. dim = abgedunkelt (zum Beispiel beim Verschieben).
static func draw(canvas: CanvasItem, rect: Rect2, item: ItemInstance, dim: bool = false) -> void:
	if item == null:
		return
	var color := ItemText.rarity_color(item.rarity)
	var alpha := 0.45 if dim else 1.0
	var inner := rect.grow(-2.0)
	var top := color.darkened(0.72)
	var bottom := color.darkened(0.86)
	top.a = 0.95 * alpha
	bottom.a = 0.95 * alpha
	var colors := PackedColorArray([top, top, bottom, bottom])
	var points := PackedVector2Array(
		[
			inner.position,
			inner.position + Vector2(inner.size.x, 0),
			inner.end,
			inner.position + Vector2(0, inner.size.y)
		]
	)
	canvas.draw_polygon(points, colors)
	var border := color
	border.a = alpha
	canvas.draw_rect(inner, border, false, 2.0 if item.rarity >= Enums.Rarity.RARE else 1.0)
	if item.base != null and item.base.icon != null:
		canvas.draw_texture_rect(item.base.icon, inner.grow(-4.0), false, Color(1, 1, 1, alpha))
	elif item.base != null:
		var glyph := color.lightened(0.25)
		glyph.a = 0.9 * alpha
		draw_slot_glyph(canvas, inner.grow(-inner.size.x * 0.18), item.base.slot, glyph, 2.5)
	if item.aspect != null or item.unique:
		var dot := inner.position + Vector2(inner.size.x - 7, 7)
		canvas.draw_circle(dot, 3.5, Color(UiTheme.ASPECT, alpha))


## Einfaches Zeichen für einen Ausrüstungsplatz (auch für leere Plätze, dann blass).
static func draw_slot_glyph(
	canvas: CanvasItem, rect: Rect2, slot: Enums.Slot, color: Color, width: float = 2.0
) -> void:
	var c := rect.get_center()
	var w := rect.size.x
	var h := rect.size.y
	match slot:
		Enums.Slot.WEAPON:
			var tip := Vector2(c.x + w * 0.35, rect.position.y + h * 0.05)
			var hilt := Vector2(c.x - w * 0.25, rect.position.y + h * 0.75)
			canvas.draw_line(hilt, tip, color, width + 1.0)
			var guard := (tip - hilt).orthogonal().normalized() * w * 0.18
			canvas.draw_line(hilt - guard, hilt + guard, color, width)
			canvas.draw_line(hilt, hilt + (hilt - tip).normalized() * h * 0.18, color, width)
		Enums.Slot.HELM:
			canvas.draw_arc(Vector2(c.x, c.y + h * 0.1), w * 0.38, PI, TAU, 16, color, width)
			canvas.draw_line(
				Vector2(c.x - w * 0.38, c.y + h * 0.1),
				Vector2(c.x + w * 0.38, c.y + h * 0.1),
				color,
				width
			)
			canvas.draw_line(
				Vector2(c.x, c.y - h * 0.1), Vector2(c.x, c.y + h * 0.35), color, width
			)
		Enums.Slot.CHEST:
			var pts := PackedVector2Array(
				[
					Vector2(c.x - w * 0.4, c.y - h * 0.3),
					Vector2(c.x - w * 0.15, c.y - h * 0.4),
					Vector2(c.x, c.y - h * 0.3),
					Vector2(c.x + w * 0.15, c.y - h * 0.4),
					Vector2(c.x + w * 0.4, c.y - h * 0.3),
					Vector2(c.x + w * 0.3, c.y + h * 0.4),
					Vector2(c.x - w * 0.3, c.y + h * 0.4),
					Vector2(c.x - w * 0.4, c.y - h * 0.3),
				]
			)
			canvas.draw_polyline(pts, color, width)
		Enums.Slot.GLOVES:
			canvas.draw_rect(
				Rect2(c.x - w * 0.25, c.y - h * 0.1, w * 0.45, h * 0.45), color, false, width
			)
			for i in 4:
				var x := c.x - w * 0.22 + i * w * 0.12
				canvas.draw_line(
					Vector2(x, c.y - h * 0.1), Vector2(x, c.y - h * 0.35), color, width
				)
		Enums.Slot.PANTS:
			var pts := PackedVector2Array(
				[
					Vector2(c.x - w * 0.3, c.y + h * 0.4),
					Vector2(c.x - w * 0.3, c.y - h * 0.35),
					Vector2(c.x + w * 0.3, c.y - h * 0.35),
					Vector2(c.x + w * 0.3, c.y + h * 0.4),
				]
			)
			canvas.draw_polyline(pts, color, width)
			canvas.draw_line(
				Vector2(c.x, c.y - h * 0.15), Vector2(c.x, c.y + h * 0.4), color, width
			)
		Enums.Slot.BOOTS:
			var pts := PackedVector2Array(
				[
					Vector2(c.x - w * 0.15, c.y - h * 0.4),
					Vector2(c.x - w * 0.15, c.y + h * 0.3),
					Vector2(c.x + w * 0.35, c.y + h * 0.3),
					Vector2(c.x + w * 0.35, c.y + h * 0.1),
					Vector2(c.x + w * 0.1, c.y),
					Vector2(c.x + w * 0.1, c.y - h * 0.4),
				]
			)
			canvas.draw_polyline(pts, color, width)
		Enums.Slot.AMULET:
			canvas.draw_arc(Vector2(c.x, c.y - h * 0.15), w * 0.3, 0.0, PI, 16, color, width)
			canvas.draw_circle(Vector2(c.x, c.y + h * 0.22), w * 0.12, color)
		Enums.Slot.RING_1, Enums.Slot.RING_2:
			canvas.draw_arc(Vector2(c.x, c.y + h * 0.08), w * 0.26, 0.0, TAU, 20, color, width)
			canvas.draw_circle(Vector2(c.x, c.y - h * 0.22), w * 0.09, color)
