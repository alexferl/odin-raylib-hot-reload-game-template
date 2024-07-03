package game

import rl "vendor:raylib"

PlayerMovementSystem :: System

player_movement_system_update :: proc(w: ^World) {
	transform := component_get(&g.player, Transform)
	physics := component_get(&g.player, Physics)

	if transform != nil && physics != nil {
		// Initialize movement direction
		move_dir := rl.Vector3{0, 0, 0}

		// Determine movement direction based on key presses
		if rl.IsKeyDown(.W) {
			move_dir.z -= 1
			move_dir.x -= 1
		}
		if rl.IsKeyDown(.S) {
			move_dir.z += 1
			move_dir.x += 1
		}
		if rl.IsKeyDown(.A) {
			move_dir.x -= 1
			move_dir.z += 1
 		}
		if rl.IsKeyDown(.D) {
			move_dir.x += 1
			move_dir.z -= 1
 		}

		// Normalize the movement direction if it's not zero
		if rl.Vector3Length(move_dir) > 0 {
			move_dir = rl.Vector3Normalize(move_dir)
		}

		// Apply move speed to get velocity
		physics.velocity.x = move_dir.x * physics.move_speed
		physics.velocity.z = move_dir.z * physics.move_speed

		dt := rl.GetFrameTime()

		// Apply gravity
		physics.velocity.y -= physics.mass * dt

		// Update player position
		new_pos := transform.position
		new_pos.x += physics.velocity.x * dt
		new_pos.z += physics.velocity.z * dt
		new_pos.y += physics.velocity.y * dt

		// Floor collision
//		floor_y := floor.pos.y + floor.size.y / 2
//		if new_pos.y <= floor_y {
//			new_pos.y = floor_y
//			player.velocity.y = 0
//		}

		// Update player position
		transform.position = new_pos
	}
}

player_movement_system := PlayerMovementSystem{
	update = player_movement_system_update,
	draw = nil,
}

RenderSystem :: System

render_system_draw :: proc(w: ^World) {
	for &e in w.entities {
		transform := component_get(&e, Transform)
		render := component_get(&e, Render)
		debug := component_get(&e, DebugRender)

		if transform != nil && render != nil {
			rl.DrawCubeV(transform.position, transform.scale, render.color)
			if debug != nil && debug.enabled {
				rl.DrawCubeWiresV(transform.position, transform.scale, debug.color)
			}
		}
	}
}

render_system := RenderSystem{
	update = nil,
	draw = render_system_draw,
}
