package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

PlayerMovementSystem :: System

player_movement_system := PlayerMovementSystem{
	update = player_movement_system_update,
	draw = nil,
}

player_movement_system_update :: proc(w: ^World) {
	camera_entity := entity_get(w, Camera)
	camera := component_get(&camera_entity, CameraComponent)
	if camera.mode == .Free {
		return
	}

	player := entity_get(w, Player)
	transform := component_get(&player, TransformComponent)
	physics := component_get(&player, PhysicsComponent)
	animation := component_get(&player, AnimationComponent)
	render := component_get(&player, RenderComponent)
	collision := component_get(&player, CollisionComponent)

	grid := entity_get(w, Grid)
	grid_collision := component_get(&grid, CollisionComponent)

	move_dir := rl.Vector3{0.0, 0.0, 0.0}

	animation.index = 1 // idle

	if rl.IsKeyDown(.W) {
		animation.index = 2 // move
		move_dir.x -= 1
		move_dir.z -= 1
	}
	if rl.IsKeyDown(.S) {
		animation.index = 2 // move
		move_dir.x += 1
		move_dir.z += 1
	}
	if rl.IsKeyDown(.A) {
		animation.index = 2 // move
		move_dir.x -= 1
		move_dir.z += 1
	}
	if rl.IsKeyDown(.D) {
		animation.index = 2 // move
		move_dir.x += 1
		move_dir.z -= 1
	}

	if rl.Vector3Length(move_dir) > 0 {
		move_dir = rl.Vector3Normalize(move_dir)

		target_angle: f32
		if abs(move_dir.x) < 0.001 && abs(move_dir.z) > 0.001 {
			// Moving primarily along Z-axis (W+D or A+S)
			target_angle = move_dir.z > 0 ? -math.PI / 2 : math.PI / 2
		} else if abs(move_dir.z) < 0.001 && abs(move_dir.x) > 0.001 {
			// Moving primarily along X-axis (W+A or S+D)
			target_angle = move_dir.x > 0 ? math.PI / 2 : -math.PI / 2
		} else {
			// Diagonal movement
			target_angle = math.atan2(move_dir.x, move_dir.z)
		}

		new_rotation := rl.QuaternionFromAxisAngle({0, 1, 0}, target_angle)

		// Apply additional rotation for Z-axis movement
		if abs(move_dir.x) < 0.001 && abs(move_dir.z) > 0.001 {
			z_axis_rotation := rl.QuaternionFromAxisAngle({0, 1, 0}, math.PI / 2)
			new_rotation = new_rotation * z_axis_rotation
		}

		transform.rotation = new_rotation
	}

	physics.velocity.x = move_dir.x * physics.move_speed
	physics.velocity.z = move_dir.z * physics.move_speed

	dt := rl.GetFrameTime()
	physics.velocity.y -= physics.mass * dt // apply gravity

	new_pos := transform.position + physics.velocity * dt

	player_box := rl.GetModelBoundingBox(render.model)
	scaled_min := player_box.min * transform.scale_factor
	scaled_max := player_box.max * transform.scale_factor
	collision.bounding_box = rl.BoundingBox{
		min = scaled_min + new_pos,
		max = scaled_max + new_pos,
	}

	has_collision := rl.CheckCollisionBoxes(collision.bounding_box, grid_collision.bounding_box)
	if has_collision {
		if new_pos.y < grid_collision.bounding_box.max.y {
			new_pos.y = grid_collision.bounding_box.max.y
			physics.velocity.y = 0
		}

		new_pos.x = math.clamp(new_pos.x, grid_collision.bounding_box.min.x, grid_collision.bounding_box.max.x)
		new_pos.z = math.clamp(new_pos.z, grid_collision.bounding_box.min.z, grid_collision.bounding_box.max.z)
	}

	transform.position = new_pos
}

CameraMovementSystem :: System

camera_movement_system := CameraMovementSystem{
	update = camera_movement_system_update,
}

camera_movement_system_update :: proc(w: ^World) {
	player_entity := entity_get(w, Player)
	player := component_get(&player_entity, TransformComponent)

	camera_entity := entity_get(w, Camera)
	camera := component_get(&camera_entity, CameraComponent)

	if rl.IsKeyPressed(.M) {
		if camera.mode == .Player {
			camera.mode = .Free

			rl.DisableCursor()

			camera.position = player.position + camera.offset
			camera.target = player.position + camera.offset

			to_player := camera.target - camera.position + camera.offset
			camera.yaw = math.atan2(-to_player.x, -to_player.z)
			camera.pitch = -math.atan2(to_player.y, math.sqrt(to_player.x*to_player.x + to_player.z*to_player.z))

			forward := rl.Vector3Normalize(to_player)
			right := rl.Vector3Normalize(rl.Vector3CrossProduct({0.0, 1.0, 0.0}, forward))
			up := rl.Vector3CrossProduct(forward, right)

			camera.up = up
		} else {
			camera.mode = .Player
			rl.EnableCursor()
		}
	}

	if camera.mode == .Player {
		camera.target = player.position
		camera.position = player.position + camera.offset
		camera.up = {0.0, 1.0, 0.0}
	} else {
		mouse_delta := rl.GetMouseDelta()

		camera.yaw -= mouse_delta.x * camera.mouse_sensitivity
		camera.pitch -= mouse_delta.y * camera.mouse_sensitivity

		// Clamp pitch to avoid flipping
		camera.pitch = math.clamp(camera.pitch, -math.PI/2 + 0.1, math.PI/2 - 0.1)

		forward := rl.Vector3{
			math.cos(camera.pitch) * math.sin(camera.yaw),
			math.sin(camera.pitch),
			math.cos(camera.pitch) * math.cos(camera.yaw),
		}
		right := rl.Vector3Normalize(rl.Vector3CrossProduct({0.0, 1.0, 0.0}, forward))
		up := rl.Vector3CrossProduct(forward, right)

		wheel_move := rl.GetMouseWheelMove()
		if wheel_move != 0 {
			zoom_factor := wheel_move * camera.movement_speed * camera.zoom_sensitivity
			camera.position = camera.position + forward * zoom_factor
		}

		move_speed := camera.movement_speed * rl.GetFrameTime()
		move_vec := rl.Vector3{0.0, 0.0, 0.0}

		if rl.IsKeyDown(.W) do move_vec = move_vec + forward
		if rl.IsKeyDown(.S) do move_vec = move_vec - forward
		if rl.IsKeyDown(.D) do move_vec = move_vec - right
		if rl.IsKeyDown(.A) do move_vec = move_vec + right

		if rl.Vector3Length(move_vec) > 0 {
			move_vec = rl.Vector3Normalize(move_vec) * move_speed
			camera.position = camera.position + move_vec
		}

		if rl.IsKeyDown(.SPACE) do camera.position.y += move_speed
		if rl.IsKeyDown(.LEFT_SHIFT) do camera.position.y -= move_speed

		camera.target = camera.position + forward
		camera.up = up
	}
}

RenderSystem :: System

render_system := RenderSystem{
	update = nil,
	draw = render_system_draw,
}

render_system_draw :: proc(w: ^World) {
	entities := entities_get_all(w)
	defer delete(entities)

	for e in entities {
		camera_entity := entity_get(w, Camera)
		camera := component_get(&camera_entity, CameraComponent)

		// 3D
		{
			rl.BeginMode3D(camera)
			{
				transform := component_get(e, TransformComponent)
				render := component_get(e, RenderComponent)
				debug := component_get(e, DebugRenderComponent)
				collision := component_get(e, CollisionComponent)
				grid := component_get(e, GridComponent)

				if grid != nil {
					rl.DrawGrid(grid.size, 1.0)
					if debug != nil && debug.enabled {
						rl.DrawBoundingBox(collision.bounding_box, rl.GREEN)
					}
				}

				if transform != nil && render != nil {
					// for model rotations, e.g.:
					// 90-degree rotation around the X-axis
					// (math.PI / 2, 0, 0)
					rotation := rl.QuaternionFromEuler(0, 0, 0)
					new_rotation := transform.rotation * rotation
					rotation_axis, rotation_angle := rl.QuaternionToAxisAngle(new_rotation)
					rotation_angle_degrees := rl.RAD2DEG * rotation_angle

					rl.DrawModelEx(
						render.model,
						transform.position,
						rotation_axis,
						rotation_angle_degrees,
						transform.scale,
						render.color,
					)

					if debug != nil && debug.enabled {
						if collision != nil {
							rl.DrawBoundingBox(collision.bounding_box, rl.RED)
						}

						forward := rl.Vector3RotateByQuaternion({0.0, 0.0, 1.0}, transform.rotation)
						end_point := transform.position + forward * 3.0
						rl.DrawLine3D(transform.position, end_point, rl.BLUE)
						rl.DrawModelWiresEx(
							render.model,
							transform.position,
							rotation_axis,
							rl.RAD2DEG * rotation_angle,
							transform.scale,
							rl.BLUE,
						)
					}
				}
			}
			rl.EndMode3D()
		}

		// 2D
		{
			rl.BeginMode2D(ui_camera())
			{
				player := entity_get(w, Player)
				transform := component_get(&player, TransformComponent)
				physics := component_get(&player, PhysicsComponent)
				text := fmt.ctprintf(
					"%d FPS\nplayer:\npos: [%.2f, %.2f, %.2f]\nvel: [%.2f, %.2f, %.2f]\ncamera:\nmode: %v (Press M)\npos: [%.2f, %.2f, %.2f]\ntarget: [%.2f, %.2f, %.2f]",
					rl.GetFPS(),
					transform.position.x, transform.position.y, transform.position.z,
					physics.velocity.x, physics.velocity.y, physics.velocity.z,
					camera.mode,
					camera.position.x, camera.position.y, camera.position.z,
					camera.target.x, camera.target.y, camera.target.z,
				)
				rl.DrawText(text, 5, 5, 8, rl.DARKGRAY)
			}
			rl.EndMode2D()
		}
	}
}

AnimationSystem :: System

animation_system := AnimationSystem{
	update = animation_system_update,
	draw = nil,
}

animation_system_update :: proc(w: ^World) {
	entities := entities_get_all(w)
	defer delete(entities)

	for e in entities {
		animation := component_get(e, AnimationComponent)
		render := component_get(e, RenderComponent)

		if animation != nil && render != nil {
			anim := animation.animations[animation.index]
			animation.current_frame = (animation.current_frame + 1) % u32(anim.frameCount)
			rl.UpdateModelAnimation(render.model, anim, i32(animation.current_frame))
		}
	}
}
