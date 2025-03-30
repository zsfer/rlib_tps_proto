package game

import la "core:math/linalg"
import rl "vendor:raylib"


Player_Animation :: enum {
	Idle = 0,
	Run,
}

Game_Memory :: struct {
	run:           bool,
	player_pos:    rl.Vector3,
	player_rot:    f32,
	player_height: f32,
	cam_fov:       f32,
	player_model:  rl.Model,
	current_anim:  Player_Animation,
	player_anims:  [^]rl.ModelAnimation,
	world_model:   rl.Model,
}


current_anim_frame := 0
player_speed :: 20
cam_sens :: 2.0
g_mem: ^Game_Memory
cam: rl.Camera3D
cam_offset :: rl.Vector3{0.0, 5.0, -10.0}

game_camera :: proc(g: ^Game_Memory) -> rl.Camera3D {
	return {
		position = g.player_pos + cam_offset,
		target = g.player_pos,
		up = {0.0, 1.0, 0.0},
		fovy = g.cam_fov,
		projection = .PERSPECTIVE,
	}
}

time_since_last_frame := f32(0)
cam_yaw := f32(0.0)
cam_pitch := f32(25.0)
follow_pos := rl.Vector3{}
targ_speed := rl.Vector3{}

update :: proc() {
	dt := rl.GetFrameTime()

	// camera stuff
	// 0.1 to slow it down
	cam_yaw -= rl.GetMouseDelta().x * 0.1 * cam_sens
	cam_pitch += rl.GetMouseDelta().y * 0.1 * cam_sens
	cam_pitch = la.clamp(cam_pitch, -70.0, 80.0)

	cam_dist := rl.Vector3Length(cam_offset)

	follow_pos = la.lerp(follow_pos, g_mem.player_pos, 10 * dt)
	targ_cam_pos :=
		follow_pos +
		rl.Vector3 {
				cam_dist * la.cos(cam_pitch * rl.DEG2RAD) * la.sin(cam_yaw * rl.DEG2RAD),
				cam_dist * la.sin(cam_pitch * rl.DEG2RAD),
				cam_dist * la.cos(cam_pitch * rl.DEG2RAD) * la.cos(cam_yaw * rl.DEG2RAD),
			}

	cam.position = targ_cam_pos
	cam.target = follow_pos + rl.Vector3{0, g_mem.player_height * 1.2, 0}

	rl.UpdateCamera(&cam, .CUSTOM)

	// player movement
	input := rl.Vector3{}

	if rl.IsKeyDown(.A) {
		input.x = -1
	}
	if rl.IsKeyDown(.D) {
		input.x = 1
	}

	if rl.IsKeyDown(.W) {
		input.z = 1
	}
	if rl.IsKeyDown(.S) {
		input.z = -1
	}

	fwd := rl.GetCameraForward(&cam)
	fwd.y = 0
	fwd = la.normalize0(fwd)
	right := rl.GetCameraRight(&cam)
	right.y = 0
	right = la.normalize0(right)

	targ_speed = la.lerp(targ_speed, la.normalize0(input), 10 * dt)
	movement := targ_speed * player_speed * dt
	dir := fwd * movement.z + right * movement.x
	g_mem.player_pos += dir

	if la.length2(movement) != 0 {
		g_mem.player_rot = la.atan2(-dir.x, -dir.z) * rl.RAD2DEG
	}

	g_mem.current_anim = la.length2(input) > 0 ? .Run : .Idle
	curr_anim := g_mem.player_anims[g_mem.current_anim]

	time_since_last_frame += dt
	framerate := f32(1.0) / f32(rl.GetFPS())
	if time_since_last_frame >= framerate {
		current_anim_frame = (current_anim_frame + 1) % auto_cast curr_anim.frameCount
		time_since_last_frame = 0
	}
	rl.UpdateModelAnimation(g_mem.player_model, curr_anim, auto_cast current_anim_frame)

}

draw :: proc() {
	rl.BeginDrawing()
	{
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(cam)

		rl.DrawModelEx(
			g_mem.player_model,
			g_mem.player_pos,
			{0, 1, 0},
			g_mem.player_rot,
			0.5,
			rl.WHITE,
		)
		rl.DrawModel(g_mem.world_model, rl.Vector3{}, 1, rl.WHITE)

		rl.EndMode3D()
	}
	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "cstone")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	anim_count := 0
	g_mem^ = Game_Memory {
		run           = true,
		cam_fov       = 60,
		player_rot    = 0,
		player_pos    = {},
		player_height = 2,
		current_anim  = .Idle,


		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		world_model   = rl.LoadModel("assets/sandbox.glb"),
		player_model  = rl.LoadModel("assets/player.glb"),
		player_anims  = rl.LoadModelAnimations("assets/player.glb", auto_cast (&anim_count)),
	}

	cam = game_camera(g_mem)

	rl.DisableCursor()
	game_hot_reloaded(g_mem)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g_mem.run
}

@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `g_mem`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
