shader_type spatial;
render_mode diffuse_burley;
uniform float breath = 0.0;
void vertex() {
 VERTEX += NORMAL * sin(VERTEX.x*2.1 + VERTEX.z*1.7 + breath) * 0.018;
}
void fragment() {
 float ribs=sin(UV.x*75.398+sin(UV.y*18.0)*1.8);
 float mottling=sin(UV.x*57.0+UV.y*31.0)*sin(UV.y*43.0-UV.x*19.0);
 vec3 base=mix(vec3(0.19,0.045,0.16),vec3(0.43,0.18,0.29),smoothstep(-0.7,0.8,mottling));
 ALBEDO=base*(0.9+0.1*ribs);
 float relief=ribs*0.0008+mottling*0.002;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
 float det=dot(dx,r1);
 if(abs(det)>0.0000001){NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(relief)*r1+dFdy(relief)*r2));}
 ROUGHNESS=mix(0.39,0.65,smoothstep(-0.5,0.65,mottling));
 SPECULAR=0.5;
}
