shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.025,0.075,0.065,1.0);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float radius=length(p-vec2(2.4,-1.0));
 float pulse=sin(radius*22.0-TIME*2.0)*0.025;
 vec3 ripple=vec3(sin(p.x*3.5+TIME*0.45)*0.04+pulse,1.0,cos(p.y*4.0-TIME*0.4)*0.04+pulse);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(ripple),0.0)).xyz);
 ALBEDO=tint.rgb;
 ROUGHNESS=0.16;
 SPECULAR=0.8;
 METALLIC=0.15;
}
