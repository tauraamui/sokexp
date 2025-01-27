module main

const window_width = 800
const window_height = 600

// game entrypoint
fn main() {
	// model_filename := "cato.obj"
	// material_filename := "cato.mtl"
	mut g_runtime := GameRuntime.new(window_width, window_height)
	g_runtime.run()
}
