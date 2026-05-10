/*
 * Copyright (c) 2025 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`include "common_pl.vh"

module vga_skeleton #( `propagated_parameter_definitions, `derived_parameter_definitions ) (
		input wire clk, reset,

		input wire [2:0] speedup,

		input wire force_x_at_thresh, force_y_at_thresh,

		output logic [5:0] rgb_out,
		output wire hsync, vsync, new_frame, new_vga_line,
		output wire active, x_active, y_active,

		output wire [10:0] scan_x0,
		output int scan_x, scan_y,
		output wire [15:0] sound_sample,
		output wire pwm_out
	);

	localparam SCAN_X0_BITS = 11;
	localparam SCAN_X_BITS = 10;
	localparam SCAN_Y_BITS = 10;//9;
	localparam VIS_Y_BITS = 9;

	localparam ACC_BITS = 10;


	// Raster scan
	// ===========
	wire signed [SCAN_X0_BITS-1:0] x0;
	wire signed [SCAN_X_BITS-1:0] x = x0[SCAN_X0_BITS-1:1];
	wire new_pixel = x0[0];
	wire signed [SCAN_Y_BITS-1:0] full_y;
	wire [VIS_Y_BITS-1:0] y = full_y ^ (1 << (VIS_Y_BITS-1));
	//wire active, x_active, y_active;
	wire new_line, x_active_start, y_hit;
	//raster_scan_c rs(
	raster_scan #(
		.USE_DOUBLE_X(1),
`ifdef USE_LINE_BUFFER
		.USE_LBUF(1)
`else
		.USE_LBUF(0)
`endif
	) rs (
		.clk(clk), .reset(reset), .en(1'b1), .speedup(speedup),
		.force_x_at_thresh(force_x_at_thresh), .force_y_at_thresh(force_y_at_thresh),
		.x(x0), .y(full_y),
		.active(active), .hsync(hsync), .vsync(vsync), .new_frame(new_frame), .active_line_done(new_line), .new_line(new_vga_line), .x_active_start(x_active_start), .y_hit(y_hit),
		.x_active(x_active), .y_active(y_active)
	);

	assign scan_x = x;
	assign scan_y = full_y;
	assign scan_x0 = x0;


	localparam MUSIC_T_BITS = `MUSIC_T_INT_BITS + 13;

	//localparam T_BITS = 9; // Increasing it to 10 makes rotation jittery for some reason? TODO: why?
	//localparam T_BITS = DXF_FRAC_BITS+2;
 	localparam T_BITS = MUSIC_T_BITS-10;

	reg signed [T_BITS-1:0] frame_t;

	always_ff @(posedge clk) begin
		if (reset) frame_t <= '0;
		else frame_t <= frame_t + new_frame;
	end


	wire new_voice_sample, new_voice_sample_pregain;
	wire signed [ACC_BITS-1:0] acc;
	wire odd_sample;
	wire gphase_override = 0;
	//wire gphase_override = odd_sample;
	music_player_wrapper dut(
		.clk(clk), .reset(reset),

		.speedup(speedup),
		.x0(x0), .y_in(full_y), .frame_t(frame_t),
		.skip_out_acc_update(gphase_override), .gphase_override(gphase_override),
//		.gphase_in({y[8:0], 1'b0}),
//		.gphase_in({frame_t, 1'b0, y[8:0]}),
//		.gphase_in({frame_t[T_BITS-1:1], 1'b0, y[8:0], 1'b0}),
//		.gphase_in({frame_t[T_BITS-1:2], 2'b0, y[8:0], 1'b0}),
		.gphase_in({frame_t[T_BITS-1:0], 2'b0, y[8:0], 1'b0}),
//		.gphase_in({frame_t[T_BITS-1:0], 3'b0, y[8:0], 1'b0}),
		.out_acc(sound_sample), .pwm_out(pwm_out),
		.odd_sample(odd_sample),
		.new_voice_sample(new_voice_sample), .new_voice_sample_pregain(new_voice_sample_pregain),
		.acc(acc)
	);


	localparam VPWM_BITS = 4;

	reg [VPWM_BITS-1:0] vpwm_counter;
	wire vpwm_level = (vpwm_counter != 0);

	always_ff @(posedge clk) begin
		if (new_voice_sample) vpwm_counter <= acc[ACC_BITS-1 -: VPWM_BITS] ^ {1'b1, {(VPWM_BITS-1){1'b0}}};
		else if (new_pixel) vpwm_counter <= vpwm_counter - vpwm_level;
	end


	wire [1:0] grey = {vpwm_level, pwm_out};
	logic [1:0] r, g, b;

	//assign rgb_out = pwm_out ? '1 : 0;

	always_comb begin
		//rgb_out = {grey, grey, grey};
		r = vpwm_level + pwm_out;
		g = {vpwm_level, 1'b0};
		b = {pwm_out, vpwm_level};
		rgb_out = {r, g, b};
		if (!active) rgb_out = '0;
	end
endmodule : vga_skeleton
