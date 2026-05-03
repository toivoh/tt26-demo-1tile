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

		output [5:0] rgb_out,
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


	// Raster scan
	// ===========
	wire signed [SCAN_X0_BITS-1:0] x0;
	wire signed [SCAN_X_BITS-1:0] x = x0[SCAN_X0_BITS-1:1];
	wire new_pixel = x0[0];
	wire signed [SCAN_Y_BITS-1:0] y;
	//wire active, x_active, y_active;
	wire new_line, x_active_start, y_hit;
	//raster_scan_c rs(
	raster_scan #(
`ifdef USE_LINE_BUFFER
		.USE_LBUF(1)
`else
		.USE_LBUF(0)
`endif
	) rs (
		.clk(clk), .reset(reset), .en(1'b1), .speedup(speedup),
		.force_x_at_thresh(force_x_at_thresh), .force_y_at_thresh(force_y_at_thresh),
		.x(x0), .y(y),
		.active(active), .hsync(hsync), .vsync(vsync), .new_frame(new_frame), .active_line_done(new_line), .new_line(new_vga_line), .x_active_start(x_active_start), .y_hit(y_hit),
		.x_active(x_active), .y_active(y_active)
	);

	assign scan_x = x;
	assign scan_y = y;
	assign scan_x0 = x0;


	localparam MUSIC_T_BITS = `MUSIC_T_INT_BITS + 13;

	//localparam T_BITS = 9; // Increasing it to 10 makes rotation jittery for some reason? TODO: why?
	//localparam T_BITS = DXF_FRAC_BITS+2;
 	localparam T_BITS = MUSIC_T_BITS-10;

	reg signed [T_BITS-1:0] t;

	always_ff @(posedge clk) begin
		if (reset) t <= '0;
		else t <= t + new_frame;
	end


	assign rgb_out = pwm_out ? '1 : 0;

`ifdef USE_MUSIC
	music_player_wrapper dut(
		.clk(clk), .reset(reset),

		.speedup(speedup),
		.x0(x0), .y_in(y), .frame_t(t),
		.out_acc(sound_sample), .pwm_out(pwm_out)
	);
`else
	assign sound_sample = '0;
`endif
endmodule : vga_skeleton
