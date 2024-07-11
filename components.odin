package game

import rl "vendor:raylib"

Transform :: struct {
    position: rl.Vector3,
    rotation: rl.Quaternion,
    scale: rl.Vector3,
	scale_factor: f32,
}

Physics :: struct {
    velocity: rl.Vector3,
    mass: f32,
    move_speed: f32,
    collider: rl.BoundingBox,
}

Render :: struct {
    color: rl.Color,
	model: rl.Model,
	animations: [^]rl.ModelAnimation,
	animations_count: i32,
	animation_index: u32,
	animation_current_frame: u32,
}

DebugRender :: struct {
	enabled: bool,
}

CameraMode :: enum {
	Player,
	Free,
}

Camera :: struct {
	using camera: rl.Camera,
	mode: CameraMode,
	offset: rl.Vector3,
	pitch: f32,
	yaw: f32,
	movement_speed: f32,
	mouse_sensitivity: f32,
	zoom_sensitivity: f32,
}

Grid :: struct {
	size: i32,
	collider: rl.BoundingBox,
}
