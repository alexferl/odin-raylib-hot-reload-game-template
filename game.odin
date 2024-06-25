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
	player_speed: f32,
	player_vel: rl.Vector3,
	player_pos: rl.Vector3,
}

g: ^Game

game_camera :: proc() -> rl.Camera3D {
	return rl.Camera3D{
		position = rl.Vector3{g.player_pos.x + 10, g.player_pos.y + 50, g.player_pos.z + 10},
		target = g.player_pos,
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
	input: rl.Vector3

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.x -= g.player_speed
		input.z -= g.player_speed
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.x += g.player_speed
		input.z += g.player_speed
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= g.player_speed
		input.z += g.player_speed
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += g.player_speed
		input.z -= g.player_speed
	}

	// don't negate inputs if pressing multiple keys
	if (rl.IsKeyDown(.UP) && rl.IsKeyDown(.LEFT)) || (rl.IsKeyDown(.W) && rl.IsKeyDown(.A)) {
		input.x -= g.player_speed
		input.z += g.player_speed
	}
	if (rl.IsKeyDown(.UP) && rl.IsKeyDown(.RIGHT)) || (rl.IsKeyDown(.W) && rl.IsKeyDown(.D)) {
		input.x += g.player_speed
		input.z -= g.player_speed
	}
	if (rl.IsKeyDown(.DOWN) && rl.IsKeyDown(.LEFT)) || (rl.IsKeyDown(.S) && rl.IsKeyDown(.A)) {
		input.x -= g.player_speed
		input.z += g.player_speed
	}
	if (rl.IsKeyDown(.DOWN) && rl.IsKeyDown(.RIGHT)) ||  (rl.IsKeyDown(.S) && rl.IsKeyDown(.D)) {
		input.x += g.player_speed
		input.z -= g.player_speed
	}

	// make sure we don't go over the max speed by pressing multiple keys
	if input.x > g.player_speed {
		input.x = g.player_speed
	}
	if input.z > g.player_speed {
		input.z = g.player_speed
	}
	if input.x < -g.player_speed {
		input.x = -g.player_speed
	}
	if input.z < -g.player_speed {
		input.z = -g.player_speed
	}

	g.player_pos += input * rl.GetFrameTime() * 100
	g.player_vel = input
}

draw :: proc() {
	rl.BeginDrawing()

	rl.ClearBackground(rl.BLACK)

	rl.BeginMode3D(game_camera())
	rl.DrawCube(g.player_pos, 2.0, 2.0, 2.0, rl.WHITE)
	rl.DrawCubeWires(g.player_pos, 2.0, 2.0, 2.0, rl.MAROON)
	rl.DrawGrid(50, 1.0)
	rl.EndMode3D()

	rl.BeginMode2D(ui_camera())
	rl.DrawText(fmt.ctprintf("player_pos: %v\nplayer_vel: %v", g.player_pos, g.player_vel), 5, 5, 8, rl.WHITE)
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
		player_speed = 0.1,
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
