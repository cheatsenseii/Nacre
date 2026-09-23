shader_type spatial;
uniform float breath = 0.0;
uniform float phase = 0.0;
varying vec3 object_position;
varying vec3 object_normal;
void vertex() {
 object_position=VERTEX;
 object_normal=NORMAL;
 VERTEX += NORMAL * sin(VERTEX.y*2.8 + VERTEX.x*1.7 + VERTEX.z*1.2 + breath + phase) * 0.065;
}
void fragment() {
 vec3 n=abs(object_normal);
 vec2 p=n.y>0.6?object_position.xz:(n.x>0.6?object_position.zy:object_position.xy);
 float folds=sin(p.x*4.0+sin(p.y*2.0)*1.3);
 float distance_to_vein=abs(sin(p.x*2.4+sin(p.y*1.8)*1.8));
 float aa=max(fwidth(distance_to_vein),0.012);
 float veins=1.0-smoothstep(0.035,0.035+aa,distance_to_vein);
 float marbling=sin(p.x*11.0+p.y*7.0)*sin(p.y*9.0-p.x*5.0);
 ALBEDO=mix(vec3(0.18,0.085,0.098),vec3(0.31,0.16,0.14),folds*0.5+0.5);
 ALBEDO*=0.91+marbling*0.09;
 ALBEDO=mix(ALBEDO,vec3(0.12,0.028,0.022),veins*0.65);
 float relief=folds*0.007+veins*0.003;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
 float det=dot(dx,r1);
 if(abs(det)>0.0000001){NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(relief)*r1+dFdy(relief)*r2));}
 ROUGHNESS=mix(0.58,0.32,veins);
 EMISSION=vec3(0.15,0.019,0.006)*veins*(0.5+0.25*sin(breath));
}
