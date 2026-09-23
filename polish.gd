extends Node3D
var game: Node
var environment: Environment
var spots: Array[SpotLight3D] = []
var quality := 1
var exposure := 1.0
var timer := 0.0
var visual_clock := 0.0
var was_editing := false
const LIGHT_LIMITS := [4,6,7,8]
const BASE_FOG_DENSITY := 0.0045
var selected_lights: Array[Light3D]=[]

func _ready() -> void:
	game=get_parent()
	for child in game.get_children():
		if child is WorldEnvironment:environment=child.environment
	environment.ambient_light_color=Color(0.47,0.51,0.53)
	var center: Vector3=game.atmosphere.mushroom_position
	for at in [Vector3(-4.8,0.014,1.5),Vector3(4.6,0.014,-1.2),center+Vector3(-8,0.014,6),center+Vector3(8,0.014,-6),center+Vector3(-7,0.014,-23),center+Vector3(7,0.014,-32)]:
		var puddle:=CylinderMesh.new();puddle.top_radius=1;puddle.bottom_radius=1;puddle.height=0.008;puddle.radial_segments=32
		var wet:=ShaderMaterial.new();wet.shader=preload("res://water.gdshader")
		var patch: MeshInstance3D=game.atmosphere.form(self,puddle,at,Vector3(0.65,1,1.2),wet)
		patch.rotation.y=at.x*0.37
		patch.add_to_group("nacre_wet_surface")
	practical(Vector3(-4,5.8,2),Color("70c7c6"),2.2,12)
	practical(Vector3(4,5.8,-1),Color("e9ba75"),1.8,10)
	practical(center+Vector3(-5,5.4,6),Color("dfd3a1"),2.0,13)
	practical(center+Vector3(5,5.4,-5),Color("84bfac"),1.8,13)
	practical(center+Vector3(0,5.5,-22),Color("79adbf"),2.5,16)
	practical(center+Vector3(0,5.5,-36),Color("e4a16f"),2.1,12)
	practical(game.combat.origin+Vector3(-5,5.4,-8),Color("88bfb8"),2.5,15)
	practical(game.combat.origin+Vector3(5,5.4,-19),Color("d7a17a"),2.8,16)
	practical(game.combat.origin+Vector3(0,5.4,-26),Color("7fbab0"),2,10)
	# Small pools of light reveal the maze's depth without flooding every passage.
	for cell in [Vector2i(4,0),Vector2i(1,1),Vector2i(7,2),Vector2i(3,4),Vector2i(1,7),Vector2i(6,7)]:
		practical(game.labyrinth.cell_at(cell)+Vector3.UP*5.02,Color("a6b4ac") if cell.x%2 else Color("c89e7f"),1.9,9)
	configure_lights(game)
	var config:=ConfigFile.new()
	if config.load("user://image.cfg")==OK:
		quality=clampi(int(config.get_value("image","quality",1)),0,3)
		exposure=clampf(float(config.get_value("image","brightness",1.0)),0.65,1.8)
	var row:=HBoxContainer.new();game.controls.panel.add_child(row)
	var title:=Label.new();title.text="IMAGE";row.add_child(title)
	var selector:=OptionButton.new()
	for name in ["Performance","Équilibré","Ambiance","Ultra"]:selector.add_item(name)
	selector.select(quality);row.add_child(selector)
	selector.item_selected.connect(func(index: int):quality=index;apply_settings();save_settings())
	var brightness:=HSlider.new();brightness.min_value=0.65;brightness.max_value=1.8;brightness.step=0.05;brightness.value=exposure
	brightness.custom_minimum_size=Vector2(190,30);brightness.tooltip_text="Luminosité des zones sombres";row.add_child(brightness)
	var caption:=Label.new();caption.text="Luminosité";row.add_child(caption)
	brightness.value_changed.connect(func(value: float):exposure=value;apply_settings())
	brightness.drag_ended.connect(func(_changed: bool):save_settings())
	brightness.focus_exited.connect(save_settings)
	apply_settings()

func practical(at: Vector3,color: Color,energy: float,reach: float) -> void:
	var spot:=SpotLight3D.new();spot.position=at;spot.rotation.x=-PI/2
	spot.light_color=color;spot.light_energy=energy;spot.spot_range=reach;spot.spot_angle=62
	spot.light_color=spot.light_color.lerp(Color(0.91,0.92,0.87),0.35)
	spot.spot_attenuation=0.5;spot.shadow_bias=0.06;spot.shadow_normal_bias=0.5
	spot.set_meta("nacre_base_energy",energy)
	spot.set_meta("nacre_flicker_phase",float(spots.size())*1.73+at.x*0.17+at.z*0.11)
	add_child(spot);spots.append(spot)
	spot.add_to_group("nacre_dynamic_light");spot.set_meta("nacre_light_priority",1)
	var case_mesh:=BoxMesh.new();case_mesh.size=Vector3(0.65,0.14,0.4)
	game.atmosphere.form(self,case_mesh,at+Vector3(0,0.06,0),Vector3.ONE,game.material(Color("253537")))
	var glass:=BoxMesh.new();glass.size=Vector3(0.5,0.035,0.3)
	game.atmosphere.form(self,glass,at-Vector3(0,0.04,0),Vector3.ONE,game.atmosphere.luminous(color,1.4))

func configure_lights(node: Node) -> void:
	for child in node.get_children():
		if child is Light3D and child!=game.torch:
			child.distance_fade_enabled=true
			child.distance_fade_begin=32;child.distance_fade_length=16
			child.add_to_group("nacre_dynamic_light")
			if not child.has_meta("nacre_light_priority"):
				child.set_meta("nacre_light_priority",2 if child.light_energy>2.4 else 0)
		configure_lights(child)

func apply_settings() -> void:
	game.get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_8X][quality]
	game.get_viewport().positional_shadow_atlas_size=4096 if quality>=2 else 2048
	environment.ambient_light_energy=0.17*exposure
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled=quality>0
	environment.fog_light_color=Color("334947");environment.fog_light_energy=0.35
	environment.fog_density=BASE_FOG_DENSITY
	# Gentle bloom makes the cyan signs and spores glow into the mist without
	# washing out the dark room. Compatibility renderer supports this pass.
	environment.glow_enabled=quality>=1
	environment.glow_intensity=0.62 if quality>=2 else 0.48
	environment.glow_bloom=0.035 if quality>=2 else 0.015
	environment.glow_hdr_threshold=0.92
	environment.adjustment_enabled=true
	environment.adjustment_brightness=1.0
	environment.adjustment_contrast=1.08 if quality>=2 else 1.03
	environment.adjustment_saturation=0.96
	if game.post_fx!=null:
		game.post_fx.visible=quality>0
		if game.post_material!=null:
			game.post_material.set_shader_parameter("vignette_strength",0.20+float(quality)*0.015)
			game.post_material.set_shader_parameter("grain_strength",0.004+float(quality)*0.001)
	game.camera.far=180
	game.torch.spot_range=16;game.torch.spot_angle=34
	game.torch.light_energy=3.5;game.torch.shadow_enabled=quality>0
	game.torch.shadow_bias=0.08;game.torch.shadow_normal_bias=0.35
	game.ceiling_light.shadow_enabled=quality>0
	var details: Node=game.get_node_or_null("Realism")
	if details!=null:details.set_quality(quality)
	update_light_budget()
	update_shadows()

func update_atmosphere(delta: float) -> void:
	visual_clock+=delta
	var fear:=0.0
	if game.horrors!=null:
		fear=clampf(float(game.horrors.fear_weight),0.0,1.0)
	var fog_target:=BASE_FOG_DENSITY
	if quality>0:
		fog_target+=fear*(0.0012 if quality==1 else 0.0022)
	if environment.fog_enabled:
		environment.fog_density=lerpf(environment.fog_density,fog_target,1.0-exp(-delta*1.8))
	if quality>=1:
		var glow_base:=0.62 if quality>=2 else 0.48
		environment.glow_intensity=lerpf(environment.glow_intensity,glow_base+fear*0.08,1.0-exp(-delta*2.0))
	for light in spots:
		if not is_instance_valid(light):continue
		var base_energy:=float(light.get_meta("nacre_base_energy",light.light_energy))
		if quality<=0 or not light.visible:
			light.light_energy=base_energy
			continue
		var phase:=float(light.get_meta("nacre_flicker_phase",0.0))
		var flutter:=(sin(visual_clock*1.7+phase)*0.015+sin(visual_clock*7.9+phase*1.6)*0.006)*(1.0+fear*1.5)
		light.light_energy=base_energy*clampf(1.0+flutter,0.92,1.05)

func update_light_budget() -> void:
	if game == null or game.player == null:return
	var ranked: Array[Dictionary]=[]
	for node in get_tree().get_nodes_in_group("nacre_dynamic_light"):
		if not node is Light3D or not is_instance_valid(node):continue
		var light: Light3D=node
		if light==game.torch or light==game.ceiling_light:continue
		if light.has_meta("horror_light"):continue
		var distance:=light.global_position.distance_squared_to(game.player.global_position)
		var priority:=float(light.get_meta("nacre_light_priority",0))
		var reach: float=light.spot_range if light is SpotLight3D else (light.omni_range if light is OmniLight3D else 12.0)
		if distance>pow(reach+5.0,2):
			light.visible=false;light.shadow_enabled=false;continue
		# Range first, then importance. Hysteresis prevents lamps swapping slots
		# with each tiny camera/player movement near equal-distance boundaries.
		var continuity:=0.14 if light in selected_lights else 0.0
		var score:=priority*0.18-sqrt(distance)/maxf(reach,1.0)+continuity
		ranked.append({"light":light,"score":score})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary):return a.score>b.score)
	var limit: int=LIGHT_LIMITS[clampi(quality,0,LIGHT_LIMITS.size()-1)]
	selected_lights.clear()
	for i in range(ranked.size()):
		var entry: Dictionary=ranked[i]
		var light: Light3D=entry.light
		var active: bool=i<limit
		light.visible=active
		if active:selected_lights.append(light)
		if not active:light.shadow_enabled=false

func update_shadows() -> void:
	var nearest: Array[SpotLight3D]=spots.duplicate()
	nearest.sort_custom(func(a: SpotLight3D,b: SpotLight3D):return a.global_position.distance_squared_to(game.player.global_position)<b.global_position.distance_squared_to(game.player.global_position))
	var used:=0
	for light in nearest:
		light.shadow_enabled=light.visible and used<quality and light.global_position.distance_squared_to(game.player.global_position)<225
		if light.shadow_enabled:used+=1

func save_settings() -> void:
	var config:=ConfigFile.new();config.set_value("image","quality",quality);config.set_value("image","brightness",exposure);config.save("user://image.cfg")

func _process(delta: float) -> void:
	if was_editing and not game.editor.active:game.combat.navigation_ready=false
	was_editing=game.editor.active
	update_atmosphere(delta)
	timer+=delta
	if timer<0.35:return
	timer=0
	if not game.front_end.active:
		update_light_budget()
		update_shadows()
