extends Node3D
## Playable Billy home prologue. Built from primitives so it runs without external assets.

var story: Node
var player: CharacterBody3D
var camera: Camera3D
var objective_label: Label
var thought_label: Label
var prompt_label: Label
var interacted := {}
var enabled := false

func _ready() -> void:
	story = get_parent().get_node_or_null("BillyPrologue")
	call_deferred("_start")

func _start() -> void:
	await get_tree().process_frame
	if story == null: return
	story.begin()
	_build_home()
	_build_ui()
	enabled = true
	_show_thought(story.current_thought)

func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color=c; m.roughness=.88; return m

func cube(name_:String,pos:Vector3,size:Vector3,c:Color,solid:=true) -> MeshInstance3D:
	var n:=MeshInstance3D.new();n.name=name_;var bm:=BoxMesh.new();bm.size=size;n.mesh=bm;n.material_override=mat(c);n.position=pos;add_child(n)
	if solid:
		var b:=StaticBody3D.new();var cs:=CollisionShape3D.new();var sh:=BoxShape3D.new();sh.size=size;cs.shape=sh;b.add_child(cs);n.add_child(b)
	return n

func _build_home() -> void:
	# Warm, slightly tired little house: living room + hall corner.
	cube("Floor",Vector3(0,-.15,0),Vector3(12,.3,10),Color("443b34"))
	cube("BackWall",Vector3(0,2.4,-5),Vector3(12,5,.25),Color("b2aa9b"))
	cube("LeftWall",Vector3(-6,2.4,0),Vector3(.25,5,10),Color("a79f91"))
	cube("RightWall",Vector3(6,2.4,0),Vector3(.25,5,10),Color("a79f91"))
	cube("Sofa",Vector3(-2,.65,-3.8),Vector3(3.8,1.3,1.2),Color("4f5b59"))
	cube("Table",Vector3(0,.45,-1.4),Vector3(2.2,.2,1.2),Color("6b4b32"))
	cube("TV",Vector3(3,1.35,-4.72),Vector3(2.5,1.45,.18),Color("17191a"),false)
	cube("PhotoNacre",Vector3(-.2,1.45,-4.82),Vector3(1.4,.9,.08),Color("37545a"),false)
	cube("Keys",Vector3(2.1,.68,-1.4),Vector3(.28,.06,.14),Color("c7b46c"),false)
	cube("UrbexGear",Vector3(-4,.55,-3.9),Vector3(.75,1.05,.55),Color("273331"),false)
	cube("Lamp",Vector3(-4.5,.7,-1.2),Vector3(.18,.55,.18),Color("d0c28e"),false)
	cube("Shoes",Vector3(4.4,.18,2.8),Vector3(.8,.3,.65),Color("312c29"),false)
	cube("Phone",Vector3(.65,.62,-1.4),Vector3(.32,.05,.62),Color("20262a"),false)
	cube("FrontDoor",Vector3(0,1.25,4.88),Vector3(1.8,2.5,.16),Color("49372b"),false)
	var light:=OmniLight3D.new();light.position=Vector3(0,3.6,0);light.light_energy=2.0;light.omni_range=10;light.light_color=Color("ffd6a3");add_child(light)
	player=CharacterBody3D.new();player.position=Vector3(0,1,1.8);add_child(player)
	var col:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=.35;cap.height=1.7;col.shape=cap;player.add_child(col)
	camera=Camera3D.new();camera.position=Vector3(0,.65,0);camera.current=true;player.add_child(camera)

func _build_ui() -> void:
	var layer:=CanvasLayer.new();layer.layer=40;add_child(layer)
	objective_label=Label.new();objective_label.position=Vector2(32,28);objective_label.size=Vector2(650,55);objective_label.add_theme_font_size_override("font_size",20);layer.add_child(objective_label)
	thought_label=Label.new();thought_label.position=Vector2(180,610);thought_label.size=Vector2(920,70);thought_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;thought_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;thought_label.add_theme_font_size_override("font_size",22);layer.add_child(thought_label)
	prompt_label=Label.new();prompt_label.position=Vector2(450,535);prompt_label.size=Vector2(380,42);prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt_label.add_theme_font_size_override("font_size",18);layer.add_child(prompt_label)
	_refresh_ui()

func _refresh_ui()->void:
	if story: objective_label.text="OBJECTIF  •  "+story.get_objective()

func _show_thought(t:String)->void:
	if t=="":return
	thought_label.text=t
	var tw:=create_tween();tw.tween_interval(4.0);tw.tween_callback(func(): if thought_label: thought_label.text="")

func _process(delta:float)->void:
	if not enabled or player==null:return
	var input:=Input.get_vector("left","right","forward","back")
	var dir:=(player.transform.basis*Vector3(input.x,0,input.y)).normalized()
	player.velocity.x=dir.x*3.3;player.velocity.z=dir.z*3.3
	if not player.is_on_floor():player.velocity.y-=12.0*delta
	player.move_and_slide()
	var target:=_target()
	prompt_label.text="" if target=="" else "[E]  "+_label(target)
	if Input.is_action_just_pressed("interact") and target!="":_interact(target)

func _target()->String:
	var best:="";var dist:=2.15
	for id in ["Lamp","Shoes","Phone","PhotoNacre","Keys","UrbexGear","FrontDoor"]:
		var n:=get_node_or_null(id)
		if n:
			var d:=player.global_position.distance_to(n.global_position)
			if d<dist:dist=d;best=id
	return best

func _label(id:String)->String:
	match id:
		"Lamp": return "Regarder la vieille lampe"
		"Shoes": return "Regarder les chaussures"
		"Phone": return "Regarder le téléphone"
		"PhotoNacre": return "Examiner la photo"
		"Keys": return "Prendre les clés"
		"UrbexGear": return "Prendre le sac d'urbex"
		"FrontDoor": return "Sortir"
	return "Interagir"

func _interact(id:String)->void:
	var line:=""
	match id:
		"Lamp","Shoes","Phone":
			if interacted.has(id):return
			interacted[id]=true
			var map={"Lamp":"urbex_lamp","Shoes":"old_shoes","Phone":"phone"}
			line=story.inspect_boredom_object(map[id])
		"PhotoNacre": line=story.inspect_nacre_photo()
		"Keys":
			line=story.collect_keys()
			if line!="":get_node("Keys").hide()
		"UrbexGear":
			line=story.collect_urbex_gear()
			if line!="":get_node("UrbexGear").hide()
		"FrontDoor":
			line=story.leave_home()
			if line!="":_leave()
	_show_thought(line);_refresh_ui()

func _leave()->void:
	enabled=false
	prompt_label.text=""
	_show_thought("Allez Billy. Une vraie sortie. Ça changera.")
	await get_tree().create_timer(2.2).timeout
	story.finish_drive()
	_show_thought("Voilà… c'était ici.")
	await get_tree().create_timer(2.2).timeout
	story.confirm_arrival()
	queue_free()
