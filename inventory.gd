extends Node
class SporeIcon extends Control:
	func _draw() -> void:
		for point in [Vector2(22,30),Vector2(38,18),Vector2(51,35),Vector2(34,43)]:
			draw_line(Vector2(36,55),point,Color(0.38,0.65,0.34),2)
			draw_circle(point,12,Color(0.5,0.85,0.25,0.16))
			draw_circle(point,7,Color(0.65,0.86,0.31))
			draw_circle(point-Vector2(2,2),2,Color(0.91,1,0.65))
var game: Node
var has_spores := false
var card: PanelContainer
var description: Label
var icon: Control
var toast: Label
var toast_time := 0.0
var resonance := 0
var pulse_clock := 0.0

func _ready() -> void:
	game=get_parent()
	card=PanelContainer.new();game.controls.panel.add_child(card)
	var row:=HBoxContainer.new();card.add_child(row)
	icon=SporeIcon.new();icon.custom_minimum_size=Vector2(78,70);row.add_child(icon)
	description=Label.new();description.custom_minimum_size=Vector2(620,70)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(description)
	var layer:=CanvasLayer.new();layer.layer=8;add_child(layer)
	toast=Label.new();toast.position=Vector2(750,155);toast.size=Vector2(490,100)
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast.add_theme_font_size_override("font_size",20)
	toast.add_theme_color_override("font_outline_color",Color.BLACK);toast.add_theme_constant_override("outline_size",5)
	layer.add_child(toast);refresh()

func refresh() -> void:
	icon.visible=has_spores
	description.text="INVENTAIRE\nSpores inconnues × 1\nUne grappe tiède offerte par le champignon. Utilité inconnue." if has_spores else "INVENTAIRE\nAucun objet mystérieux."

func resonate(level: int, announce: bool = true) -> void:
	resonance=clampi(level,0,3)
	refresh()
	if not has_spores:return
	var clues := [
		"Une grappe tiède offerte par le champignon. Utilité inconnue.",
		"Les spores battent au rythme du premier nœud.",
		"Chaque nœud réveille les spores. L’ombre semble suivre leur pulsation.",
		"Le cadeau est une marque vivante. Quelque chose te suit à son odeur."
	]
	description.text="INVENTAIRE\nSpores inconnues × 1\n"+clues[resonance]
	if announce and resonance>0:
		toast.text=clues[resonance];toast_time=5

func grant_spores() -> void:
	if has_spores:return
	has_spores=true;refresh()
	toast.text="Objet reçu : Spores inconnues × 1\nAjouté à l'inventaire — F1 pour examiner."
	toast_time=6

func restore(owned: bool) -> void:
	has_spores=owned;toast_time=0;resonate(game.labyrinth.collected.count(true),false)

func consume_spores() -> bool:
	if not has_spores:return false
	has_spores=false;refresh()
	toast.text="Spores du grand champignon : chargées dans la cuve."
	toast_time=4
	return true

func _process(delta: float) -> void:
	if not game.paused and not game.editor.active:
		toast_time=maxf(0,toast_time-delta)
		pulse_clock+=delta
		icon.modulate=Color.WHITE*(1.0+sin(pulse_clock*(2.0+resonance))*0.18 if has_spores and resonance>0 else 1.0)
	toast.visible=toast_time>0 and not game.editor.active and not game.paused
