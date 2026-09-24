extends Node
class HitMark extends Control:
 var remaining:=0.0
 var lethal:=false
 func _draw() -> void:
  if remaining<=0:return
  var center:=Vector2(640,360)
  var color:=Color("e6b16c") if lethal else Color("b3f4df")
  color.a=minf(1,remaining*6)
  for side in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
   draw_line(center+side*9,center+side*17,color,2,true)
var game: Node
var layer: CanvasLayer
var heading: Label
var objective: Label
var marker: HitMark
var grace:=0.0
var buffer:=0.0
var last_position:=Vector3.ZERO
var room:=""
var title_time:=0.0
var room_title: Label
var announced_quest := ""

func _ready() -> void:
 game=get_parent();last_position=game.player.position
 layer=CanvasLayer.new();layer.layer=8;add_child(layer)
 var panel:=Panel.new();panel.position=Vector2(900,24);panel.size=Vector2(350,104);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style: StyleBoxFlat=game.front_end.style(Color("102b33"));style.bg_color.a=0.9;style.border_color=Color("377d7e");style.border_width_left=3;panel.add_theme_stylebox_override("panel",style);layer.add_child(panel)
 heading=game.front_end.label(panel,"OBJECTIF",Vector2(16,10),13,Color("77cfc4"));heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 objective=game.front_end.label(panel,"",Vector2(16,34),17,Color("e3eee8"));objective.size=Vector2(318,64);objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;objective.mouse_filter=Control.MOUSE_FILTER_IGNORE
 marker=HitMark.new();marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(marker)
 room_title=game.front_end.label(layer,"",Vector2(330,130),25,Color("cae8df"));room_title.size=Vector2(620,40);room_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;room_title.mouse_filter=Control.MOUSE_FILTER_IGNORE

func move_player(delta: float,direction: Vector3,speed: float) -> void:
 if game.player.position.distance_to(last_position)>3:grace=0;buffer=0
 var grounded: bool=game.player.is_on_floor()
 var fall_speed:=maxf(0.0,-game.player.velocity.y)
 grace=0.12 if grounded else maxf(0,grace-delta)
 buffer=maxf(0,buffer-delta)
 if Input.is_action_just_pressed("jump"):buffer=0.14
 var acceleration: float=24 if grounded else 9
 game.player.velocity.x=move_toward(game.player.velocity.x,direction.x*speed,acceleration*delta)
 game.player.velocity.z=move_toward(game.player.velocity.z,direction.z*speed,acceleration*delta)
 if not grounded:game.player.velocity.y-=18*delta
 else:game.player.velocity.y=0
 if buffer>0 and grace>0 and not game.actions.crouched:
  game.player.velocity.y=5.8;buffer=0;grace=0
 game.player.move_and_slide()
 if not grounded and game.player.is_on_floor() and fall_speed>4.2:
  var impact:=clampf((fall_speed-4.2)/28.0,0.025,0.12)
  if game.third_person!=null and game.third_person.has_method("shake"):
   game.third_person.shake(impact,0.10+impact*0.35)
  if fall_speed>8.0 and game.has_method("pulse_post_fx"):
   game.pulse_post_fx(clampf((fall_speed-8.0)/28.0,0.05,0.16),0.10)
 last_position=game.player.position

func hit(lethal: bool) -> void:
 marker.remaining=0.35;marker.lethal=lethal;marker.queue_redraw()
 if game.third_person!=null and game.third_person.has_method("shake"):
  game.third_person.shake(0.11 if lethal else 0.045,0.18 if lethal else 0.11)
 if game.has_method("pulse_post_fx"):
  game.pulse_post_fx(0.65 if lethal else 0.25,0.24 if lethal else 0.14)

func current_goal() -> Array[String]:
 if game.silence!=null and game.silence.inside():return ["CHAMBRE DU SILENCE",game.silence.goal()]
 if game.horrors!=null and game.horrors.inside():return ["SALLE DES HORREURS",game.horrors.goal()]
 if game.torture!=null and game.torture.inside():return ["LOCAL ÉLECTRIQUE",game.torture.goal()]
 if game.simon.inside():return ["ANIMATION AQUATIQUE", "Reproduis les quatre séquences." if not game.simon.won else "Le mécanisme a cédé. La porte suivante est libre."]
 if not game.arrived:return ["DESCENTE 01","Approche du toboggan. Le fond reste invisible."]
 if game.combat.inside():
  if not game.combat.equipped:return ["BASSIN DE MAINTENANCE","Une épée est coincée dans l’alcôve de gauche."]
  var alive:=0
  for enemy in game.combat.enemies:
   if int(enemy.get_meta("hp"))>0:alive+=1
  return ["BASSIN DE MAINTENANCE","Il en reste %d." % alive if alive>0 else "Le bassin est calme. Rejoins la sortie."]
 if game.labyrinth.inside():
  var count: int=game.labyrinth.collected.count(true)
  return ["GALERIES SOUS LES BASSINS","Nœuds éveillés : %d / 3. Évite l’Ombre." % count if count<3 else "Les trois nœuds répondent. Trouve la sortie."]
 if game.feeding.inside() and game.puzzle.solved:
  return ["ANCIEN BASSIN","Le Grand Champignon t’a laissé quelque chose. Rejoins le fond du bassin."]
 if not game.puzzle.solved:
  if not game.feeding.equipped:return ["ANCIEN BASSIN","Un vieux bâton traîne près de l’arrivée."]
  return ["ANCIEN BASSIN","La créature bloque le passage." if game.feeding.hp>0 else "Ne bouge pas. Le champignon vient de réagir."]
 return ["CHAMBRE DU SILENCE","Les deux vannes alimentent encore le réseau. Coupe-les."]

func _process(delta: float) -> void:
 layer.visible=not game.paused and not game.editor.active and not game.front_end.active and not game.sliding
 if not layer.visible:
  grace=0;buffer=0;marker.remaining=0;return
 marker.remaining=maxf(0,marker.remaining-delta);marker.queue_redraw()
 var goal:=current_goal();heading.text=goal[0];objective.text=goal[1]
 if room!=goal[0]:
  room=goal[0];room_title.text=room;title_time=3
  var quest_key := ""
  match room:
   "DESCENTE 01":quest_key="mission"
   "ANCIEN BASSIN":quest_key="mushroom_quest"
   "CHAMBRE DU SILENCE":quest_key="galleries_quest"
   "GALERIES SOUS LES BASSINS":quest_key="labyrinth_quest"
   "BASSIN DE MAINTENANCE":quest_key="combat_quest"
   "LOCAL ÉLECTRIQUE":quest_key="torture_quest"
  if quest_key!="" and quest_key!=announced_quest:
   announced_quest=quest_key;game.voice.say(quest_key)
 title_time=maxf(0,title_time-delta);room_title.modulate.a=minf(1,title_time)
