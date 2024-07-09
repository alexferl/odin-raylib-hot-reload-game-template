// This file is compiled as part of the `odin.dll` file. It contains the
// procs that `game.exe` will call, such as:
//
// game_init: Sets up the game state
// game_update: Run once per frame
// game_shutdown: Shuts down game and frees memory
// game_memory: Run just before a hot reload, so game.exe has a pointer to the
//		game's memory.
// game_hot_reloaded: Run after a hot reload so that the `g_mem` global variable
//		can be set to whatever pointer it was in the old DLL.

package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

DEV :: #config(DEV, false)

PIXEL_WINDOW_HEIGHT :: 360

Game :: struct {
	camera: Entity,
	grid: Entity,
	player: Entity,
	world: World,
}

g: ^Game

ui_camera :: proc() -> rl.Camera2D {
	return {
		zoom = f32(rl.GetScreenHeight())/PIXEL_WINDOW_HEIGHT,
	}
}

update :: proc() {
	world_update(&g.world)
}

draw :: proc() {
	camera := component_get(&g.camera, Camera)

	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)

	// 3D mode
	{
		rl.BeginMode3D(camera)
		{
			world_draw(&g.world)
		}
		rl.EndMode3D()
	}

	// 2D mode
	{
		rl.BeginMode2D(ui_camera())
		{
			transform := component_get(&g.player, Transform)
			physics := component_get(&g.player, Physics)
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

	rl.EndDrawing()
}

@(export)
game_update :: proc() -> bool {
	update()
	draw()
	return !rl.WindowShouldClose()
}

when DEV {
	WINDOW_FLAGS :: rl.ConfigFlags { .WINDOW_RESIZABLE, .VSYNC_HINT }
} else {
	WINDOW_FLAGS :: rl.ConfigFlags { .VSYNC_HINT }
}

toggle_fullscreen :: proc() {
	when DEV {
		rl.ToggleBorderlessWindowed()
	} else {
		if rl.IsWindowFullscreen() {
			rl.SetWindowState(WINDOW_FLAGS + { .WINDOW_RESIZABLE} )
			rl.SetWindowSize(1280, 720)
			rl.ShowCursor()
		} else {
			w := rl.GetMonitorWidth(rl.GetCurrentMonitor())
			h := rl.GetMonitorHeight(rl.GetCurrentMonitor())
			rl.ClearWindowState({ .WINDOW_RESIZABLE })
			rl.ToggleFullscreen()
			rl.SetWindowSize(w, h)
			rl.HideCursor()
		}
	}
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags(WINDOW_FLAGS)
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(60)

	when !DEV {
		rl.SetTraceLogLevel(.WARNING)
		toggle_fullscreen()
	}
}

@(export)
game_init :: proc() {
	g = new(Game)

	world := world_init(DEFAULT_WORLD_NAME)

	// Camera
	camera := entity_create(&world)
	component_add(&camera, Camera{
		camera = rl.Camera{
			position = {10.0, 10.0, 10.0},
			target = {0.0, 0.0, 0.0},
			up = {0.0, 1.0, 0.0},
			fovy = 45.0,
			projection = .PERSPECTIVE,
		},
		mode = .Player,
		offset = {20.0, 20.0, 20.0},
		movement_speed = 20.0,
		mouse_sensitivity = 0.002,
		zoom_sensitivity = 0.1,
	})

	// Player
	model := rl.LoadModel("assets/greenman.glb")
	anims_count : i32 = 0
	anims := rl.LoadModelAnimations("assets/greenman.glb", &anims_count)

	player_pos := rl.Vector3{0.0, 10.0, 0.0}
	player := entity_create(&world)
	component_add(&player, Transform{
		position = player_pos,
		rotation = rl.QuaternionFromEuler(0, math.PI, 0),
		scale = {2.0, 2.0, 2.0},
	})
	player_bounding_box := rl.GetModelBoundingBox(model)
	component_add(&player, Physics{
		mass = 15.0,
		move_speed = 10.0,
		collider =  rl.BoundingBox{
			player_bounding_box.min + player_pos,
			player_bounding_box.max + player_pos,
		},
	})
	component_add(&player, Render{
		model = model,
		animations = anims,
		animations_count = anims_count,
		animation_index = 1, // idle
		color = rl.WHITE,
	})
	component_add(&player, DebugRender{enabled = true, color = rl.RED})

	// Grid
	grid := entity_create(&world)
	grid_size : f32 = 40
	component_add(&grid, Grid{
		size = i32(grid_size),
		collider = rl.BoundingBox{
			rl.Vector3{-grid_size/2, -0.1, -grid_size/2},
			rl.Vector3{grid_size/2, 0.1, grid_size/2},
		},
	})

	system_add(&world, player_movement_system)
	system_add(&world, camera_movement_system)
	system_add(&world, render_system)

	g^ = Game{
		camera = camera,
		grid = grid,
		player = player,
		world = world,
	}

	game_hot_reloaded(g)
}

@(export)
game_shutdown :: proc() {
	world_destroy(&g.world)
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}
