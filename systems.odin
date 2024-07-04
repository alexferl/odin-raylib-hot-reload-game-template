package game

import "core:math"
import rl "vendor:raylib"

PlayerMovementSystem :: System

player_movement_system_update :: proc(w: ^World) {
	camera := component_get(&g.camera, Camera)
	if camera.mode == .Free {
		return
	}

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

CameraMovementSystem :: System

camera_movement_system_update :: proc(w: ^World) {
	camera := component_get(&g.camera, Camera)
	player := component_get(&g.player, Transform)

	if rl.IsKeyPressed(.M) {
		if camera.mode == .Player {
			camera.mode = .Free

			rl.DisableCursor()  // Hide and lock cursor in free camera mode

			// Set initial free camera position and target
			camera.position = player.position + camera.offset
			camera.target = player.position + camera.offset

			// Calculate initial yaw and pitch
			to_player := camera.target - camera.position + camera.offset
			camera.yaw = math.atan2(-to_player.x, -to_player.z)
			camera.pitch = -math.atan2(to_player.y, math.sqrt(to_player.x*to_player.x + to_player.z*to_player.z))

			// Ensure the camera is using the correct orientation
			forward := rl.Vector3Normalize(to_player)
			right := rl.Vector3Normalize(rl.Vector3CrossProduct({0, 1, 0}, forward))
			up := rl.Vector3CrossProduct(forward, right)

			camera.up = up
		} else {
			camera.mode = .Player
			rl.EnableCursor()  // Show and unlock cursor in player-following mode
		}
	}

	if camera.mode == .Player {
		// Player-following camera
		camera.target = player.position
		camera.position = player.position + camera.offset
		camera.up = {0.0, 1.0, 0.0}
	} else {
		// Mouse look
		mouse_delta := rl.GetMouseDelta()

		// Update yaw and pitch
		camera.yaw -= mouse_delta.x * camera.mouse_sensitivity
		camera.pitch -= mouse_delta.y * camera.mouse_sensitivity

		// Clamp pitch to avoid flipping
		camera.pitch = math.clamp(camera.pitch, -math.PI/2 + 0.1, math.PI/2 - 0.1)

		// Calculate new forward vector
		forward := rl.Vector3{
			math.cos(camera.pitch) * math.sin(camera.yaw),
			math.sin(camera.pitch),
			math.cos(camera.pitch) * math.cos(camera.yaw),
		}

		// Calculate right vector
		right := rl.Vector3Normalize(rl.Vector3CrossProduct({0, 1, 0}, forward))

		// Calculate up vector
		up := rl.Vector3CrossProduct(forward, right)

		// Zoom with mouse wheel
		wheel_move := rl.GetMouseWheelMove()
		if wheel_move != 0 {
			zoom_factor := wheel_move * camera.movement_speed * camera.zoom_sensitivity
			camera.position = camera.position + forward * zoom_factor
		}

		// Movement
		move_speed := camera.movement_speed * rl.GetFrameTime()
		move_vec := rl.Vector3{0, 0, 0}

		if rl.IsKeyDown(.W) do move_vec = move_vec + forward
		if rl.IsKeyDown(.S) do move_vec = move_vec - forward
		if rl.IsKeyDown(.D) do move_vec = move_vec - right
		if rl.IsKeyDown(.A) do move_vec = move_vec + right

		if rl.Vector3Length(move_vec) > 0 {
			move_vec = rl.Vector3Normalize(move_vec) * move_speed
			camera.position = camera.position + move_vec
		}

		// Vertical movement
		if rl.IsKeyDown(.SPACE) do camera.position.y += move_speed
		if rl.IsKeyDown(.LEFT_SHIFT) do camera.position.y -= move_speed

		// Update camera target
		camera.target = camera.position + forward
		camera.up = up
	}
}

camera_movement_system := CameraMovementSystem{
	update = camera_movement_system_update,
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
