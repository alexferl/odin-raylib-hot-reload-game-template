package game

import rl "vendor:raylib"

TransformComponent :: struct {
    position: rl.Vector3,
    rotation: rl.Quaternion,
    scale: rl.Vector3,
	scale_factor: f32,
}

PhysicsComponent :: struct {
    velocity: rl.Vector3,
    mass: f32,
    move_speed: f32,
}

CollisionComponent :: struct {
	bounding_box: rl.BoundingBox,
}

RenderComponent :: struct {
    color: rl.Color,
	model: rl.Model,
}

DebugRenderComponent :: struct {
	enabled: bool,
}

AnimationComponent :: struct {
	animations: [^]rl.ModelAnimation,
	count: i32,
	index: u32,
	current_frame: u32,
}

CameraMode :: enum {
	Player,
	Free,
}

CameraComponent :: struct {
	using camera: rl.Camera,
	mode: CameraMode,
	offset: rl.Vector3,
	pitch: f32,
	yaw: f32,
	movement_speed: f32,
	mouse_sensitivity: f32,
	zoom_sensitivity: f32,
}

GridComponent :: struct {
	size: i32,
}
