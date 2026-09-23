extends RefCounted
# Shared normal maps generated once; colour remains editable in the wardrobe.
static var fabric: ImageTexture
static var pores: ImageTexture

static func normal_map(woven: bool) -> ImageTexture:
	if woven and fabric!=null:return fabric
	if not woven and pores!=null:return pores
	var image:=Image.create(128,128,false,Image.FORMAT_RGB8)
	var noise:=FastNoiseLite.new();noise.seed=1998;noise.frequency=0.13
	for y in range(128):
		for x in range(128):
			var dx: float
			var dy: float
			if woven:
				dx=sin(x*TAU/8.0)*0.3*(0.65+0.35*cos(y*TAU/16.0))
				dy=sin(y*TAU/8.0)*0.3*(0.65-0.35*cos(x*TAU/16.0))
			else:
				dx=(noise.get_noise_2d(x+1,y)-noise.get_noise_2d(x-1,y))*1.8
				dy=(noise.get_noise_2d(x,y+1)-noise.get_noise_2d(x,y-1))*1.8
			var n:=Vector3(dx,dy,1).normalized()*0.5+Vector3.ONE*0.5
			image.set_pixel(x,y,Color(n.x,n.y,n.z))
	image.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(image)
	if woven:fabric=texture
	else:pores=texture
	return texture

static func apply(mat: StandardMaterial3D,woven: bool) -> void:
	mat.normal_enabled=true;mat.normal_texture=normal_map(woven)
	mat.normal_scale=0.45 if woven else 0.8
	mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*(3.0 if woven else 1.6)
	mat.roughness=0.88 if woven else 0.58
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
