extends Node
const COLORS = [Color("c48887"),Color("357d83"),Color("454e60"),Color("92764a"),Color("792f41"),Color("b7b6ad")]
const HAIR = [Color("7f6241"),Color("352b26"),Color("bd995f"),Color("87452d"),Color("9c9b94")]
var game: Node
var active := false
var layer: CanvasLayer
var preview: Node3D
var view: SubViewport
var status: Label
var choices := {"haut":0,"pantalon":2,"sac":2,"cheveux":0,"barbe":true,"sac_visible":true}
var widgets: Dictionary = {}
var previous_pause := false

func _ready() -> void:
 game=get_parent()
 tag(game.third_person.avatar)
 var cfg:=ConfigFile.new()
 if cfg.load("user://apparence.cfg")==OK:
  for key in choices:
   var value: Variant=cfg.get_value("look",key,choices[key])
   if choices[key] is bool:
    if value is bool:choices[key]=value
   elif value is int:choices[key]=clampi(value,0,4 if key=="cheveux" else 5)
 apply(game.third_person.avatar)
 build_menu()
 var button:=Button.new();button.text="APPARENCE DU PERSONNAGE";button.pressed.connect(open)
 game.controls.panel.add_child(button)
 game.front_end.button("APPARENCE",5,open)

func tag(node: Node) -> void:
 if node is MeshInstance3D and node.material_override is StandardMaterial3D:
  var color: Color=node.material_override.albedo_color
  var hex:=color.to_html(false)
  var group: String=""
  if hex in ["c48887","e0a8a3","875a60","805a60","9f6d70","a16d70","aa7275","e0aba5","af797d","d09a98"]:group="haut"
  elif hex in ["30363d","454952"]:group="pantalon"
  elif hex in ["222a31","333d45","28323a","171f25"]:group="sac"
  elif hex in ["7f6241","765335"]:group="cheveux"
  node.set_meta("original_color",color);node.set_meta("look_group",group)
  node.set_meta("pack_detail",node.get_parent()==game.third_person.avatar and hex in ["222a31","63717a"])
  node.set_meta("is_beard",group=="cheveux" and node.position.y< -0.025)
  node.material_override=node.material_override.duplicate()
 for child in node.get_children():tag(child)

func apply(node: Node) -> void:
 if node is MeshInstance3D and node.has_meta("look_group"):
  var group: String=node.get_meta("look_group")
  if group!="":
   var original: Color=node.get_meta("original_color")
   var color: Color=HAIR[choices[group]] if group=="cheveux" else COLORS[choices[group]]
   if (group=="haut" and choices[group]==0) or (group in ["pantalon","sac"] and choices[group]==2) or (group=="cheveux" and choices[group]==0):color=original
   else:color=color.darkened(clampf(0.5-original.v,0,0.3))
   node.material_override.albedo_color=color
  if node.get_meta("is_beard",false):node.visible=choices.barbe
  if group=="sac" or node.get_meta("pack_detail",false):node.visible=choices.sac_visible
 if node.name=="Sac_detaille":node.visible=choices.sac_visible
 for child in node.get_children():apply(child)

func build_menu() -> void:
 layer=CanvasLayer.new();layer.layer=110;add_child(layer);layer.hide()
 var background:=ColorRect.new();background.color=Color("091d27");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(background)
 game.front_end.label(layer,"TON PERSONNAGE",Vector2(65,45),32,Color("b7eee3"))
 game.front_end.label(layer,"Choisis ton look avant de retourner dans le noir.",Vector2(65,95),17,Color("a9c5c5"))
 var y:=150
 for key in ["haut","pantalon","sac","cheveux"]:
  game.front_end.label(layer,key.capitalize(),Vector2(65,y),19,Color.WHITE)
  var option:=OptionButton.new();option.position=Vector2(65,y+30);option.size=Vector2(360,38);layer.add_child(option)
  var names: Array=["Châtain","Brun","Blond","Roux","Gris"] if key=="cheveux" else ["Rose","Pétrole","Sombre","Sable","Bordeaux","Clair"]
  for title in names:option.add_item(title)
  option.select(choices[key]);widgets[key]=option
  option.item_selected.connect(func(index: int):choices[key]=index;changed())
  y+=83
 for key in ["barbe","sac_visible"]:
  var toggle:=CheckButton.new();toggle.text="Barbe" if key=="barbe" else "Porter le sac"
  toggle.position=Vector2(65,y);toggle.button_pressed=choices[key];layer.add_child(toggle);widgets[key]=toggle
  toggle.toggled.connect(func(value: bool):choices[key]=value;changed());y+=42
 var container:=SubViewportContainer.new();container.position=Vector2(510,125);container.size=Vector2(660,470);layer.add_child(container)
 view=SubViewport.new();view.size=Vector2i(660,470);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_DISABLED;container.add_child(view)
 var camera:=Camera3D.new();camera.fov=38;camera.position=Vector3(0,1.15,-3.2);view.add_child(camera);camera.look_at(Vector3(0,0.95,0));camera.current=true
 var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("10242b");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("9cbabb");env.ambient_light_energy=0.3;environment.environment=env;view.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,155,0);light.light_color=Color("e6d5b9");light.light_energy=1.5;light.shadow_enabled=true;view.add_child(light)
 var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-20,-35,0);rim.light_color=Color("76b9b1");rim.light_energy=0.85;view.add_child(rim)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-10,-135,0);fill.light_color=Color("9eb5ca");fill.light_energy=0.35;view.add_child(fill)
 var platform:=MeshInstance3D.new();var base:=CylinderMesh.new();base.top_radius=0.65;base.bottom_radius=0.70;base.height=0.14;base.radial_segments=48;platform.mesh=base;platform.position.y=-0.075;platform.material_override=game.material(Color("263a3e"));view.add_child(platform)
 var slider:=HSlider.new();slider.position=Vector2(630,610);slider.size=Vector2(420,25);slider.min_value=-180;slider.max_value=180;layer.add_child(slider)
 slider.value_changed.connect(func(value: float):if is_instance_valid(preview):preview.rotation.y=deg_to_rad(value))
 game.front_end.label(layer,"Tourner le personnage",Vector2(720,645),15,Color("a9c5c5"))
 status=game.front_end.label(layer,"",Vector2(65,590),15,Color("e8bd76"))
 var back:=Button.new();back.text="RETOUR";back.position=Vector2(65,645);back.size=Vector2(360,45);back.pressed.connect(close);layer.add_child(back)

func open() -> void:
 if active:return
 active=true;previous_pause=game.paused;game.paused=true
 if is_instance_valid(preview):preview.free()
 preview=game.third_person.avatar.duplicate();view.add_child(preview);preview.position=Vector3.ZERO;preview.rotation=Vector3.ZERO;preview.scale=Vector3(1,1,1.3);preview.show()
 # Preview is a neutral pose, without combat weapons.
 for limb in [game.third_person.left_arm,game.third_person.right_arm,game.third_person.left_leg,game.third_person.right_leg]:
  preview.get_child(limb.get_index()).rotation=Vector3.ZERO
 var right_index: int=game.third_person.right_arm.get_index()
 var right: Node=preview.get_child(right_index)
 right.get_child(game.third_person.blade.get_index()).hide();right.get_child(game.third_person.staff.get_index()).hide()
 apply(preview);layer.show();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func changed() -> void:
 apply(game.third_person.avatar)
 if is_instance_valid(preview):apply(preview)
 var cfg:=ConfigFile.new()
 for key in choices:cfg.set_value("look",key,choices[key])
 status.text="Apparence sauvegardée." if cfg.save("user://apparence.cfg")==OK else "Sauvegarde impossible. Apparence appliquée pour cette session."

func close() -> void:
 active=false;layer.hide();view.render_target_update_mode=SubViewport.UPDATE_DISABLED;game.paused=previous_pause
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if game.paused else Input.MOUSE_MODE_CAPTURED
