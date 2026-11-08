// Gentle sway for plant sprites: the top of the sprite moves, the soil line
// stays put. Phase comes from the world position so neighbors don't move in
// sync. Pixel snapping keeps the motion pixel-art friendly (1 px steps).
shader_type canvas_item;

uniform float amplitude = 0.8;   // pixels at the top of the sprite
uniform float speed = 1.6;
uniform float sprite_height = 12.0;

void vertex() {
	// Sprite offset puts the soil line near y = 0 and the top at y = -12.
	float height_factor = clamp(-VERTEX.y / sprite_height, 0.0, 1.0);
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = origin.x * 0.15 + origin.y * 0.05;
	VERTEX.x += sin(TIME * speed + phase) * amplitude * height_factor;
}
