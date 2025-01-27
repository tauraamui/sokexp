module main

import gg
import time
import lib.obj

const cato_obj_filename = "cato.obj"

struct GameRuntime {
mut:
	gg          &gg.Context = unsafe { nil }

	frame_count int
	ticks       i64

	cato_model  &obj.ObjPart = unsafe { nil }
}

fn GameRuntime.new(window_width int, window_height int) &GameRuntime {
	mut g_runtime := &GameRuntime{}
	g_runtime.gg = gg.new_context(
		width: window_width
		height: window_height
		create_window: true
		window_title: "sokexp"
		user_data: g_runtime
		init_fn: init
		frame_fn: frame
		cleanup_fn: cleanup
		event_fn: event
	)
	return g_runtime
}

fn (mut g_runtime GameRuntime) load_models_and_materials() {
	mut cato_object := &obj.ObjPart{}
	obj_file_lines := obj.read_lines_from_file(cato_obj_filename)
}

fn init(mut g_runtime GameRuntime) {
	g_runtime.load_models_and_materials()
}

fn frame(mut g_runtime GameRuntime) {}

fn event(mut ev gg.Event, mut g_runtime GameRuntime) {}

fn cleanup(mut g_runtime GameRuntime) {}

fn (mut g_runtime GameRuntime) run() {
	g_runtime.ticks = time.ticks()
	g_runtime.gg.run()
}
