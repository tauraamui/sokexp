module main

import gg
import gg.m4
import gx
import math
import time
import lib.obj
import sokol.sapp
import sokol.gfx
import sokol.sgl
import os

// GSLS include and functions
#include "@VMODROOT/src/gouraud.h"

fn C.gouraud_shader_desc(gfx.Backend) &gfx.ShaderDesc

const cato_obj_filename = "floor.obj"

struct GameRuntime {
mut:
	gg				&gg.Context = unsafe { nil }
	texture			gfx.Image
	sampler			gfx.Sampler
	init_flag		bool

	frame_count		int
	ticks			i64
	single_material_flag bool

	obj_part &obj.ObjPart = unsafe { nil }
	cato_model  &obj.ObjPart = unsafe { nil }
}

fn GameRuntime.new(window_width int, window_height int) &GameRuntime {
	mut g_runtime := &GameRuntime{
		single_material_flag: false
	}
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
	cato_object.parse_obj_buffer(obj_file_lines, g_runtime.single_material_flag)
	cato_object.summary()
	g_runtime.obj_part = cato_object

	// set max verts
	// for a large numer of the same type of object it is better to use instances
	desc := sapp.create_desc()
	gfx.setup(&desc)
	sgl_desc := sgl.Desc{
		max_vertices: 128 * 65536
	}
	sgl.setup(&sgl_desc)

	// 1x1 pixel white, default texture
	unsafe {
		tmp_txt := malloc(4)
		tmp_txt[0] = u8(0xFF)
		tmp_txt[1] = u8(0xFF)
		tmp_txt[2] = u8(0xFF)
		tmp_txt[3] = u8(0xFF)
		g_runtime.texture, g_runtime.sampler = obj.create_texture(1, 1, tmp_txt)
		free(tmp_txt)
	}
	// glsl
	g_runtime.obj_part.init_render_data(g_runtime.texture, g_runtime.sampler)
}

fn (mut g_runtime GameRuntime) frame() {
	mut color_action := gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{
			r: 0.0
			g: 0.0
			b: 0.0
			a: 1.0
		}
	}

	mut pass_action := gfx.PassAction{}
	pass_action.colors[0] = color_action
	pass := sapp.create_default_pass(pass_action)
	gfx.begin_pass(&pass)

	// render the data
	if g_runtime.init_flag == false {
		return
	}
	ws := gg.window_size_real_pixels()
	gfx.apply_viewport(0, 0, ws.width, ws.height, true)

	defer {
		gfx.end_pass()
		gfx.commit()
	}

	draw_model(g_runtime, m4.Vec4{})

	g_runtime.frame_count += 1
}

/******************************************************************************
* Draw functions
******************************************************************************/
@[inline]
fn vec4(x f32, y f32, z f32, w f32) m4.Vec4 {
	return m4.Vec4{
		e: [x, y, z, w]!
	}
}

fn calc_matrices(w f32, h f32, rx f32, ry f32, in_scale f32, pos m4.Vec4) obj.Mats {
	proj := m4.perspective(60, w / h, 0.01, 100.0) // set far plane to 100 fro the zoom function
	view := m4.look_at(vec4(f32(0.0), 0, 6, 0), vec4(f32(0), 0, 0, 0), vec4(f32(0), 1,
		0, 0))
	view_proj := view * proj

	rxm := m4.rotate(m4.rad(rx), vec4(f32(1), 0, 0, 0))
	rym := m4.rotate(m4.rad(ry), vec4(f32(0), 1, 0, 0))

	model_pos := m4.unit_m4().translate(pos)

	model_m := (rym * rxm) * model_pos
	scale_m := m4.scale(vec4(in_scale, in_scale, in_scale, 1))

	mv := scale_m * model_m // model view
	nm := mv.inverse().transpose() // normal matrix
	mvp := mv * view_proj // model view projection

	return obj.Mats{
		mv:  mv
		mvp: mvp
		nm:  nm
	}
}


fn draw_model(g_runtime GameRuntime, model_pos m4.Vec4) u32 {
	if g_runtime.init_flag == false {
		return 0
	}

	ws := gg.window_size_real_pixels()
	dw := ws.width / 2
	dh := ws.height / 2

	mut scale := f32(1)
	if g_runtime.obj_part.radius > 1 {
		scale = 1 / (g_runtime.obj_part.radius)
	} else {
		scale = g_runtime.obj_part.radius
	}
	scale *= 3

	// *** vertex shader uniforms ***
	// rot := [f32(app.mouse_y), f32(app.mouse_x)]
	rot := [f32(0), f32(0)]
	// mut zoom_scale := scale + f32(app.scroll_y) / (app.obj_part.radius * 4)
	zoom_scale := 1
	mats := calc_matrices(dw, dh, rot[0], rot[1], zoom_scale, model_pos)

	mut tmp_vs_param := obj.Tmp_vs_param{
		mv:  mats.mv
		mvp: mats.mvp
		nm:  mats.nm
	}

	// *** fragment shader uniforms ***
	time_ticks := f32(time.ticks() - g_runtime.ticks) / 1000
	radius_light := f32(g_runtime.obj_part.radius)
	x_light := f32(math.cos(time_ticks) * radius_light)
	z_light := f32(math.sin(time_ticks) * radius_light)

	mut tmp_fs_params := obj.Tmp_fs_param{}
	tmp_fs_params.light = m4.vec3(x_light, radius_light, z_light)

	sd := obj.Shader_data{
		vs_data: unsafe { &tmp_vs_param }
		vs_len:  int(sizeof(tmp_vs_param))
		fs_data: unsafe { &tmp_fs_params }
		fs_len:  int(sizeof(tmp_fs_params))
	}

	return g_runtime.obj_part.bind_and_draw_all(sd)
}

fn (mut g_runtime GameRuntime) event(mut ev gg.Event) {

}

fn (mut g_runtime GameRuntime) cleanup() {

}

fn init(mut g_runtime GameRuntime) {
	g_runtime.load_models_and_materials()
	g_runtime.init_flag = true
}

fn frame(mut g_runtime GameRuntime) {
	g_runtime.frame()
}

fn event(mut ev gg.Event, mut g_runtime GameRuntime) {
	g_runtime.event(mut ev)
}

fn cleanup(mut g_runtime GameRuntime) {
	g_runtime.cleanup()
}

fn (mut g_runtime GameRuntime) run() {
	g_runtime.ticks = time.ticks()
	g_runtime.gg.run()
}
