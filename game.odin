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
import rl "vendor:raylib"

DEV :: #config(DEV, false)

PIXEL_WINDOW_HEIGHT :: 180

Game :: struct {
	free_cam: bool,
	player_pos: rl.Vector3,
	player_speed: f32,
	player_vel: rl.Vector3,
}

g: ^Game

cam := free_camera()

game_camera :: proc() -> rl.Camera3D {
	return rl.Camera3D{
		position = rl.Vector3{g.player_pos.x + 10, g.player_pos.y + 50, g.player_pos.z + 10},
		target = g.player_pos,
		up = rl.Vector3{0.0, 1.0, 0.0},
		fovy = 45.0,
		projection = rl.CameraProjection.PERSPECTIVE,
	}
}

free_camera :: proc() -> rl.Camera3D {
	return rl.Camera3D{
		position = rl.Vector3{10.0, 10.0, 10.0},
		target = rl.Vector3{0.0, 0.0, 0.0},
		up = rl.Vector3{0.0, 1.0, 0.0},
		fovy = 45.0,
		projection = rl.CameraProjection.PERSPECTIVE,
	}
}

ui_camera :: proc() -> rl.Camera2D {
	return {
		zoom = f32(rl.GetScreenHeight())/PIXEL_WINDOW_HEIGHT,
	}
}

update :: proc() {
	if rl.IsKeyPressed(.M) {
		g.free_cam = !g.free_cam
	}

	if !g.free_cam {
		input()
	}
}

input :: proc() {
	input: rl.Vector3
	speed := g.player_speed/100

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.x -= speed
		input.z -= speed
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.x += speed
		input.z += speed
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= speed
		input.z += speed
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += speed
		input.z -= speed
	}

	// don't negate inputs if pressing multiple keys
	if (rl.IsKeyDown(.UP) && rl.IsKeyDown(.LEFT)) || (rl.IsKeyDown(.W) && rl.IsKeyDown(.A)) {
		input.x -= speed
		input.z += speed
	}
	if (rl.IsKeyDown(.UP) && rl.IsKeyDown(.RIGHT)) || (rl.IsKeyDown(.W) && rl.IsKeyDown(.D)) {
		input.x += speed
		input.z -= speed
	}
	if (rl.IsKeyDown(.DOWN) && rl.IsKeyDown(.LEFT)) || (rl.IsKeyDown(.S) && rl.IsKeyDown(.A)) {
		input.x -= speed
		input.z += speed
	}
	if (rl.IsKeyDown(.DOWN) && rl.IsKeyDown(.RIGHT)) ||  (rl.IsKeyDown(.S) && rl.IsKeyDown(.D)) {
		input.x += speed
		input.z -= speed
	}

	// make sure we don't go over the max speed by pressing multiple keys
	if input.x > speed {
		input.x = speed
	}
	if input.z > speed {
		input.z = speed
	}
	if input.x < -speed {
		input.x = -speed
	}
	if input.z < -speed {
		input.z = -speed
	}

	g.player_pos += input * rl.GetFrameTime() * 100
	g.player_vel = input*100
}

draw :: proc() {
	cam_mode := "PLAYER"
	if !g.free_cam  {
		cam = game_camera()
		rl.UpdateCamera(&cam, rl.CameraMode.ORBITAL)
	} else {
		cam_mode = "FREE"
		rl.UpdateCamera(&cam, rl.CameraMode.FREE)
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode3D(cam)
	rl.DrawCube(g.player_pos, 2.0, 2.0, 2.0, rl.WHITE)
	rl.DrawCubeWires(g.player_pos, 2.0, 2.0, 2.0, rl.RED)
	rl.DrawGrid(50, 1.0)
	rl.EndMode3D()

	rl.BeginMode2D(ui_camera())
	text := fmt.ctprintf(
		"player:\npos: [%.2f, %.2f, %.2f]\nvel: %v\ncamera:\nmode: %v (Press M)\npos: [%.2f, %.2f, %.2f]\ntarget: [%.2f, %.2f, %.2f]",
		g.player_pos.x, g.player_pos.y, g.player_pos.z, g.player_vel, cam_mode, cam.position.x, cam.position.y, cam.position.z, cam.target.x, cam.target.y, cam.target.z,
	)
	rl.DrawText(text, 5, 5, 8, rl.WHITE)
	rl.EndMode2D()

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
	rl.SetExitKey(nil)
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)

	when !DEV {
		rl.SetTraceLogLevel(.WARNING)
		toggle_fullscreen()
	}
}

@(export)
game_init :: proc() {
	g = new(Game)

	g^ = Game{
		player_speed = 10.0,
	}

	game_hot_reloaded(g)
}

@(export)
game_shutdown :: proc() {
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
