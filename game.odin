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

import "core:math"
import rl "vendor:raylib"

DEV :: #config(DEV, false)

PIXEL_WINDOW_HEIGHT :: 360

Game :: struct {
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
	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)

	world_draw(&g.world)

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
	camera := entity_create(&world, Camera, new(Camera))
	component_add(&camera, CameraComponent{
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
	player := entity_create(&world, Player, new(Player))

	pos := rl.Vector3{0.0, 10.0, 0.0}
	scale_factor : f32 = 1.0

	component_add(&player, TransformComponent{
		position = pos,
		rotation = rl.QuaternionFromEuler(0, math.PI, 0),
		scale = rl.Vector3{1.0, 1.0, 1.0} * scale_factor,
		scale_factor = scale_factor,
	})

	component_add(&player, PhysicsComponent{
		mass = 15.0,
		move_speed = 10.0,
	})

	model := rl.LoadModel("assets/greenman.glb")
	anims_count : i32 = 0
	anims := rl.LoadModelAnimations("assets/greenman.glb", &anims_count)

	player_bounding_box := rl.GetModelBoundingBox(model)
	scaled_min := player_bounding_box.min * scale_factor
	scaled_max := player_bounding_box.max * scale_factor
	component_add(&player, CollisionComponent{
		bounding_box = rl.BoundingBox{
			min = scaled_min + pos,
			max = scaled_max + pos,
		},
	})

	component_add(&player, RenderComponent{
		model = model,
		color = rl.WHITE,
	})
	component_add(&player, DebugRenderComponent{enabled = true})

	component_add(&player, AnimationComponent{
		animations = anims,
		count = anims_count,
		index = 1, // idle
	})

	// Grid
	grid := entity_create(&world, Grid, new(Grid))
	grid_size : f32 = 40

	component_add(&grid, GridComponent{
		size = i32(grid_size),
	})

	component_add(&grid, CollisionComponent{
		bounding_box = rl.BoundingBox{
			rl.Vector3{-grid_size/2, -0.1, -grid_size/2},
			rl.Vector3{grid_size/2, 0.1, grid_size/2},
		},
	})

	component_add(&grid, DebugRenderComponent{enabled = true})

	// Systems
	system_add(&world, player_movement_system)
	system_add(&world, camera_movement_system)
	system_add(&world, render_system)
	system_add(&world, animation_system)

	g^ = Game{
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
