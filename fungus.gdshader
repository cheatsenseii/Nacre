shader_type spatial;
render_mode diffuse_burley;
varying vec3 at;
void vertex(){at=VERTEX;VERTEX+=NORMAL*sin(TIME*0.8+VERTEX.y*2.0)*0.025;}
void fragment(){
 float angle=atan(at.z,at.x);
 float veins=pow(abs(sin(angle*28.0+sin(length(at.xz)*8.0)*0.5)),18.0);
 float bands=0.5+0.5*sin(length(at.xz)*22.0+sin(angle*7.0));
 ALBEDO=mix(vec3(0.11,0.035,0.17),vec3(0.35,0.10,0.32),bands*0.6);
 EMISSION=vec3(0.13,0.5,0.35)*veins*(0.3+0.12*sin(TIME*0.8));
 ROUGHNESS=0.42;
}
