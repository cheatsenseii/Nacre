extends Node3D
const BODY = preload("res://fonts/Interface.ttf")
const BOLD = preload("res://fonts/Signaletique.ttf")
var game: Node3D
var gate_sign: Label3D
var stick_sign: Label3D
var panels := 0

func _ready() -> void:
	game=get_parent()
	var labels: Array[Label3D]=[]
	collect(game,labels)
	for sign in labels:
		if sign.has_meta("simon_symbol"):continue
		if sign.text in ["N A C R E","CENTRE AQUATIQUE • BASSIN 01"]:
			sign.hide();continue
		style_sign(sign)
	brand()
	mascot_poster()
	style_interface(game)

func collect(node: Node,output: Array[Label3D]) -> void:
	for child in node.get_children():
		if child is Label3D:output.append(child)
		collect(child,output)

func style_interface(node: Node) -> void:
	if node is Control:
		node.add_theme_font_override("font",BODY)
		if node is Label:node.add_theme_font_override("font",BODY)
	for child in node.get_children():style_interface(child)

func plate(parent: Node3D,size: Vector2,at: Vector3,color: Color) -> void:
	var mesh:=QuadMesh.new();mesh.size=size
	var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.position=at
	var mat:=StandardMaterial3D.new();mat.albedo_color=color
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED;instance.material_override=mat
	parent.add_child(instance)

func style_sign(sign: Label3D) -> void:
	var words:=sign.text
	var category:="ARCHIVES DU PARC"
	var accent:=Color("c0b391")
	var font: Font=BODY
	if "CHAMBRE" in words or "GALERIE" in words or "SECTEUR" in words or "ACCUEIL" in words or words=="LA SERRE AVEUGLE":
		category="NACRE / REPÉRAGE";accent=Color("65ccc7");font=BOLD
	elif "UN BÂTON" in words:
		category="OBJET À RAMASSER";accent=Color("dcca7a");font=BOLD;stick_sign=sign
		sign.text="BÂTON\nPour te défendre"
	elif "NŒUD VITAL" in words:
		category="INTERACTION";accent=Color("aed89a");font=BOLD
	elif "PASSAGE" in words or "SCEAU" in words:
		category="ACCÈS";accent=Color("65ccc7");font=BOLD
		if words=="PASSAGE SCELLÉ":gate_sign=sign
	elif "NE " in words or "INCONNUE" in words or "FERMÉ" in words:
		category="AVERTISSEMENT";accent=Color("e1aa64")
	elif "FER DORT" in words or "CULTURE" in words:
		category="INDICE";accent=Color("dcca7a")
	sign.font=font
	sign.font_size=42 if font==BOLD else 36
	sign.pixel_size=0.0035
	sign.width=860;sign.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sign.modulate=Color("e8eee8");sign.outline_modulate=Color("0a2028");sign.outline_size=3
	sign.shaded=false
	var measured: Vector2=font.get_multiline_string_size(sign.text,HORIZONTAL_ALIGNMENT_CENTER,860,sign.font_size)
	var height:=maxf(0.28,measured.y*sign.pixel_size)
	var width:=minf(3.2,maxf(1.7,measured.x*sign.pixel_size+0.35))
	plate(sign,Vector2(width,height+0.4),Vector3(0,0.06,-0.035),Color("102b33"))
	plate(sign,Vector2(0.035,height+0.4),Vector3(-width/2+0.025,0.06,-0.025),accent)
	var heading:=Label3D.new();heading.text=category;heading.font=BOLD;heading.font_size=20
	heading.pixel_size=0.0035;heading.modulate=accent;heading.outline_size=0
	heading.position=Vector3(0,height/2+0.14,0.006);sign.add_child(heading)
	panels+=1

func brand() -> void:
	var mesh:=QuadMesh.new();mesh.size=Vector2(7,1.575)
	var logo:=MeshInstance3D.new();logo.name="Logo_Nacre"
	logo.mesh=mesh;logo.position=Vector3(0,6.18,-3.65)
	var mat:=StandardMaterial3D.new();mat.albedo_texture=preload("res://branding/nacre.svg")
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED;logo.material_override=mat;add_child(logo)

func _process(_delta: float) -> void:
	if is_instance_valid(gate_sign):
		var text: String="PASSAGE OUVERT" if game.puzzle.solved else "PASSAGE FERMÉ"
		if gate_sign.text!=text:gate_sign.text=text
	if is_instance_valid(stick_sign):stick_sign.visible=not game.feeding.equipped and not game.puzzle.solved

func mascot_poster() -> void:
	var poster:=Node3D.new();poster.name="Affiche_Mascotte_Nacre";poster.position=Vector3(5.81,2.65,0.5);poster.rotation.y=-PI/2;add_child(poster)
	plate(poster,Vector2(2.2,3.25),Vector3(0,0,-0.012),Color("477e83"))
	var panel:=MeshInstance3D.new();panel.name="Illustration"
	var quad:=QuadMesh.new();quad.size=Vector2(2.08,3.12);panel.mesh=quad
	var mat:=StandardMaterial3D.new();mat.albedo_texture=preload("res://branding/mascotte_nacre.png")
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;panel.material_override=mat;poster.add_child(panel)
	var caption:=Label3D.new();caption.text="TON SOURIRE NOUS MANQUAIT.";caption.font=BOLD
	caption.font_size=28;caption.pixel_size=0.003;caption.position=Vector3(0,-1.78,0.01);caption.modulate=Color("b1d1cb");poster.add_child(caption)
