shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.37,0.5,0.48,1.0);
uniform float floor_level = 0.0;
uniform bool tiles = true;
uniform bool metal = false;
varying vec3 world;
varying vec3 local_normal;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;local_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 n=abs(local_normal);
 vec2 uv=n.y>0.6?world.xz:(n.x>0.6?world.zy:world.xy);
 float broad=noise(uv*0.55)*0.7+noise(uv*2.4)*0.3;
 float detail=1.0-smoothstep(0.01,0.035,length(fwidth(uv)));
 float grit=mix(0.5,noise(uv*74.0),detail);
 vec3 col=tint.rgb*(0.72+0.36*broad+0.09*grit);
 float relief=(grit-0.5)*0.0007;
 float roughness=0.8;
 float damp=(1.0-smoothstep(0.0,2.2,world.y-floor_level))*smoothstep(0.36,0.7,noise(uv*1.8));
 col=mix(col,col*vec3(0.35,0.5,0.36),damp*0.75);
 if(n.y<0.6){
  float runoff=noise(vec2(uv.x*8.0,uv.y*0.45));
  col*=1.0-smoothstep(0.57,0.83,runoff)*0.22;
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
  float chip=step(0.94,hash(floor(cell)))*smoothstep(0.72,0.9,noise(cell*5.0));
  col=mix(col,vec3(0.15,0.14,0.12),chip*0.8);
  // Fine fractures stay inside individual tiles; no repeated full-wall scratches.
  vec2 tile_id=floor(cell);
  float fracture=abs(fract(cell.y)-0.3-0.17*sin(fract(cell.x)*8.0+hash(tile_id)*11.0));
  float crack=(1.0-smoothstep(0.004,0.004+aa,fracture))*step(0.79,hash(tile_id+21.0))*(1.0-grout);
  col=mix(col,vec3(0.085,0.105,0.09),crack*0.75);
  relief-=crack*0.0012;
  // Ceramic dado strip ties every room to the old aquatic centre.
  if(n.y<0.6){
   float h=world.y-floor_level;
   float band=smoothstep(1.13,1.15,h)*(1.0-smoothstep(1.37,1.39,h));
   col=mix(col,col*vec3(0.24,0.66,0.73),band*(1.0-grout));
  }
 }
 if(metal){
  float rust=smoothstep(0.5,0.77,broad+grit*0.15);
  col=mix(col,vec3(0.29,0.13,0.045),rust*0.7);
  METALLIC=0.55;
  METALLIC=mix(0.7,0.04,rust);
  roughness=mix(0.33,0.91,rust);
  relief+=(rust-0.5)*0.001;
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
