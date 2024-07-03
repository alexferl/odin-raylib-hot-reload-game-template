package game

import rl "vendor:raylib"

Transform :: struct {
    position: rl.Vector3,
    rotation: rl.Vector3,
    scale: rl.Vector3,
}

Physics :: struct {
    velocity: rl.Vector3,
    mass: f32,
    move_speed: f32,
    collider: rl.BoundingBox,
}

Render :: struct {
    color: rl.Color,
}

DebugRender :: struct {
	enabled: bool,
	color: rl.Color,
}
