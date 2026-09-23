extends Node3D
var game: Node3D
var lights: Array[OmniLight3D] = []
var tubes: Array[MeshInstance3D] = []
var elapsed := 0.0
var stable_lighting := false
var switch_panel: Button

func _ready() -> void:
	game=get_parent()
	var center: Vector3=game.atmosphere.mushroom_position
	var next:=center+Vector3(0,0,-26)
	for side in [-1.0,1.0]:
		for z in [-10.0,-2.0,6.0]:
			game.puzzle.block(next+Vector3(side*5.8,1.9,z),Vector3(0.3,3.8,4.6),Color(0.16,0.22,0.24))
			fixture(next+Vector3(side*8.1,4.8,z),Color(0.8,0.34,0.11) if side<0 else Color(0.2,0.55,0.85))
			game.puzzle.block(next+Vector3(side*9.2,0.6,z+1),Vector3(2.2,1.2,0.8),Color(0.19,0.23,0.24))
	fixture(Vector3(-4,4,-1),Color(0.8,0.4,0.15))
	fixture(Vector3(4,4,2),Color(0.2,0.6,0.63))
	# One obvious toggle in the existing pause menu; preferences persist independently.
	var config:=ConfigFile.new()
	if config.load("user://ambiance.cfg")==OK:stable_lighting=bool(config.get_value("ambiance","stable",false))
	var panel: Node=game.controls.panel
	switch_panel=Button.new()
	switch_panel.text="Lumières : "+("stables" if stable_lighting else "vacillantes")
	switch_panel.pressed.connect(func():
		stable_lighting=not stable_lighting
		switch_panel.text="Lumières : "+("stables" if stable_lighting else "vacillantes")
		var settings:=ConfigFile.new()
		settings.set_value("ambiance","stable",stable_lighting)
		settings.save("user://ambiance.cfg")
	)
	panel.add_child(switch_panel)

func fixture(at: Vector3,color: Color) -> void:
	var mesh:=BoxMesh.new();mesh.size=Vector3(1.7,0.09,0.12)
	var material: Material=game.atmosphere.luminous(color,1.4)
	var tube: MeshInstance3D=game.atmosphere.form(self,mesh,at,Vector3.ONE,material)
	tubes.append(tube)
	var light:=OmniLight3D.new();light.position=at+Vector3(0,-0.25,0)
	light.light_color=color;light.omni_range=7.5;light.light_energy=1.5
	add_child(light);lights.append(light)
	light.add_to_group("nacre_dynamic_light");light.set_meta("nacre_light_priority",0)

func _process(delta: float) -> void:
	if game.paused or game.editor.active:return
	elapsed+=delta
	for i in range(lights.size()):
		# Slow, staggered dimming over 6–10 seconds; no full-screen flashes.
		var wave:=0.5+0.5*sin(elapsed*(0.65+float(i%4)*0.12)+i*1.9)
		var energy:=1.3 if stable_lighting else lerpf(0.16,1.7,smoothstep(0.12,0.88,wave))
		lights[i].light_energy=energy
		tubes[i].material_override.emission_energy_multiplier=energy
