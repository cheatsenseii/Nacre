shader_type spatial;
render_mode diffuse_burley;

uniform vec4 tint : source_color = vec4(0.37,0.5,0.48,1.0);
uniform float floor_level = 0.0;
uniform bool tiles = true;
uniform bool metal = false;
uniform float grime_amount = 0.5;
uniform float wetness = 0.5;
uniform float rust_amount = 0.7;
uniform float algae_amount = 0.15;
uniform float mineral_amount = 0.4;
uniform float wear_amount = 0.6;
uniform float surface_seed = 0.0;

varying vec3 world;
varying vec3 local_normal;

float hash(vec2 p){ return fract(sin(dot(p+surface_seed,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){
	vec2 i=floor(p),f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void vertex(){
	world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	local_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment(){
	vec3 n=abs(local_normal);
	vec2 uv=n.y>0.6?world.xz:(n.x>0.6?world.zy:world.xy);
	vec2 seeded=uv+vec2(surface_seed*1.73,surface_seed*0.91);
	float broad=noise(seeded*0.55)*0.7+noise(seeded*2.4)*0.3;
	float detail=1.0-smoothstep(0.01,0.035,length(fwidth(uv)));
	float grit=mix(0.5,noise(seeded*74.0),detail);
	float micro=noise(seeded*18.0+8.2);
	vec3 col=tint.rgb*(0.72+0.36*broad+0.09*grit);
	float relief=(grit-0.5)*0.0007;
	float roughness=0.8;

	float low_zone=1.0-smoothstep(0.0,2.6,world.y-floor_level);
	float damp_pattern=smoothstep(0.32,0.72,noise(seeded*1.8));
	float damp=clamp(low_zone*damp_pattern*wetness,0.0,1.0);
	col=mix(col,col*vec3(0.34,0.48,0.39),damp*0.78);
	roughness=mix(roughness,0.24,damp*0.62);

	float grime_noise=noise(seeded*0.88+vec2(7.0,2.0))*0.68+noise(seeded*4.7)*0.32;
	float grime=smoothstep(0.54,0.82,grime_noise)*grime_amount;
	if(n.y<0.68){
		float runoff=noise(vec2(seeded.x*7.5,seeded.y*0.38)+3.1);
		float streak=smoothstep(0.58,0.86,runoff)*grime_amount;
		col*=1.0-streak*0.25;
		grime=max(grime,streak*0.75);
	}
	col=mix(col,col*vec3(0.36,0.4,0.34),clamp(grime,0.0,0.82));

	float algae_mask=low_zone*smoothstep(0.53,0.78,noise(seeded*2.2+11.0))*algae_amount;
	col=mix(col,vec3(0.075,0.19,0.12)*(0.72+0.35*micro),clamp(algae_mask,0.0,0.72));
	roughness=mix(roughness,0.9,algae_mask*0.55);
	relief+=(algae_mask-0.15)*0.0012;

	if(n.y<0.7){
		float mineral_line=noise(vec2(seeded.x*3.5,seeded.y*0.24)+19.0);
		float mineral=smoothstep(0.73,0.91,mineral_line)*mineral_amount*(0.35+0.65*low_zone);
		col=mix(col,vec3(0.55,0.59,0.52),clamp(mineral*0.58,0.0,0.55));
		roughness=mix(roughness,0.98,mineral*0.45);
		relief+=mineral*0.0011;
	}

	if(tiles){
		vec2 cell=uv*1.8;
		vec2 edge=min(fract(cell),1.0-fract(cell));
		float aa=max(0.006,length(fwidth(cell))*0.5);
		float grout=1.0-smoothstep(0.018-aa,0.018+aa,min(edge.x,edge.y));
		col*=0.85+0.22*hash(floor(cell));
		col=mix(col,vec3(0.055,0.065,0.059),grout);
		relief-=grout*0.0025;
		roughness=mix(mix(0.5,0.22,damp),0.94,grout);
		float chip=step(0.94,hash(floor(cell)+surface_seed))*smoothstep(0.72,0.9,noise(cell*5.0+surface_seed));
		col=mix(col,vec3(0.15,0.14,0.12),chip*0.8*wear_amount);
		vec2 tile_id=floor(cell);
		float fracture=abs(fract(cell.y)-0.3-0.17*sin(fract(cell.x)*8.0+hash(tile_id)*11.0));
		float crack=(1.0-smoothstep(0.004,0.004+aa,fracture))*step(0.79,hash(tile_id+21.0+surface_seed))*(1.0-grout)*wear_amount;
		col=mix(col,vec3(0.085,0.105,0.09),crack*0.75);
		relief-=crack*0.0012;
		if(n.y<0.6){
			float h=world.y-floor_level;
			float band=smoothstep(1.13,1.15,h)*(1.0-smoothstep(1.37,1.39,h));
			col=mix(col,col*vec3(0.24,0.66,0.73),band*(1.0-grout));
		}
	}

	if(metal){
		float rust_noise=broad*0.72+grit*0.14+noise(seeded*5.3)*0.14;
		float rust=smoothstep(0.5,0.77,rust_noise)*rust_amount;
		float scratches=smoothstep(0.8,0.94,noise(vec2(seeded.x*1.2,seeded.y*19.0)+4.0))*wear_amount;
		col=mix(col,vec3(0.29,0.13,0.045),clamp(rust*0.72,0.0,0.88));
		col=mix(col,col*1.22,scratches*0.16*(1.0-clamp(rust,0.0,1.0)));
		METALLIC=mix(0.7,0.04,clamp(rust,0.0,1.0));
		roughness=mix(0.33,0.91,clamp(rust,0.0,1.0));
		relief+=(rust-0.5)*0.0012-scratches*0.0007;
	}

	vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
	vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
	float determinant=dot(dx,r1);
	if(abs(determinant)>0.0000001){
		vec3 gradient=sign(determinant)*(dFdx(relief)*r1+dFdy(relief)*r2);
		NORMAL=normalize(abs(determinant)*NORMAL-gradient);
	}
	ALBEDO=col;
	ROUGHNESS=roughness;
	SPECULAR=0.45;
}
