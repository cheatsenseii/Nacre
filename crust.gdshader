shader_type spatial;
render_mode cull_disabled, diffuse_burley, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(0.18,0.24,0.18,1.0);
uniform float density = 0.65;
uniform float roughness_value = 0.92;
uniform float seed = 0.0;

float hash(vec2 p){
	return fract(sin(dot(p + seed,vec2(127.1,311.7)))*43758.5453);
}

float noise(vec2 p){
	vec2 i=floor(p);
	vec2 f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}

void fragment(){
	vec2 p=UV*vec2(5.0,3.0);
	float macro=noise(p*0.72)+noise(p*2.1)*0.42+noise(p*5.7)*0.18;
	float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
	float breakup=smoothstep(0.48,0.78,macro*density+edge*0.55);
	if(breakup<0.48) discard;
	float freckles=smoothstep(0.58,0.82,noise(p*11.0+4.7));
	ALBEDO=tint.rgb*(0.72+0.22*macro)+freckles*0.035;
	ROUGHNESS=roughness_value;
	SPECULAR=0.28;
}
