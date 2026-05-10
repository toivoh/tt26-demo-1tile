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


	wire [1:0] delta_mul;
	wire [8:0] t_dy = frame_t;
	logic [9:0] delta_y;

	logic dy_en, dy_2x, dy_inv;
	always_comb begin
		dy_en = 'X; dy_2x = 'X; dy_inv = 'X;
		case (delta_mul)
			//0: begin; dy_en = 1; dy_2x = 1; dy_inv = 1; end // -1
			0: begin; dy_en = 1; dy_2x =  0; dy_inv =  1; end // -1
			1: begin; dy_en = 0; dy_2x = 'X; dy_inv = 'X; end //  0
			2: begin; dy_en = 1; dy_2x =  0; dy_inv =  0; end // -1
			3: begin; dy_en = 1; dy_2x =  1; dy_inv =  0; end // -1
			default: begin; dy_en = 'X; dy_2x = 'X; dy_inv = 'X; end
		endcase

		delta_y = t_dy;
		if (dy_inv) delta_y = (~delta_y)&511;
		if (dy_2x) delta_y = delta_y << 1;
		if (!dy_en) delta_y = 0;
	end

	wire [10:0] y_eff = y + delta_y;

	wire new_voice_sample, new_voice_sample_pregain;
	wire signed [ACC_BITS-1:0] acc;
	wire odd_sample;
	//wire gphase_override = 0;
	wire gphase_override = odd_sample;
	wire [4:0] voice;
	music_player_wrapper mplayer(
		.clk(clk), .reset(reset),

		.speedup(speedup),
		.x0(x0), .y_in(full_y), .frame_t(frame_t),
		.skip_out_acc_update(gphase_override), .gphase_override(gphase_override),
//		.gphase_in({y[8:0], 1'b0}),
		.gphase_in({y_eff, 1'b0}),
//		.gphase_in({frame_t, 1'b0, y[8:0]}),
//		.gphase_in({frame_t[T_BITS-1:1], 1'b0, y[8:0], 1'b0}),
//		.gphase_in({frame_t[T_BITS-1:2], 2'b0, y[8:0], 1'b0}),
//		.gphase_in({frame_t[T_BITS-1:0], 2'b0, y[8:0], 1'b0}),
//		.gphase_in({frame_t[T_BITS-1:0], 3'b0, y[8:0], 1'b0}),
		.voice(voice),
		.out_acc(sound_sample), .pwm_out(pwm_out),
		.odd_sample(odd_sample),
		.new_voice_sample(new_voice_sample), .new_voice_sample_pregain(new_voice_sample_pregain),
		.acc(acc), .delta_mul_out(delta_mul)
	);


	localparam VPWM_BITS = 4;

	reg [VPWM_BITS-1:0] vpwm_counter;
//	wire vpwm_level = (vpwm_counter != 0) || !gphase_override;
	wire vpwm_level = (vpwm_counter != 0) && gphase_override;

	always_ff @(posedge clk) begin
		if (new_voice_sample) vpwm_counter <= acc[ACC_BITS-1 -: VPWM_BITS] ^ {1'b1, {(VPWM_BITS-1){1'b0}}};
		else if (new_pixel) vpwm_counter <= vpwm_counter - vpwm_level;
	end


	wire [1:0] used_value = ~((frame_t >> (4+3)) + voice);
	//wire [1:0] palette = 0;
	//wire [1:0] palette = frame_t >> (8+3);

	localparam PART_BITS = 3;

	wire [PART_BITS-1:0] part = frame_t[T_BITS-1:11];
	wire [1:0] pattern = frame_t[10:9];
	wire [1:0] measure = frame_t[8:7];
	wire in_gap = (voice[3:2] == 1);

	logic [1:0] palette;
	logic [PART_BITS-1:0] part_eff;
	logic alt_part;
	logic lock_dx2_en, lock_dx2_partial, inverse_video;

	always_comb begin
		palette = 0;
		lock_dx2_en = 0;
		lock_dx2_partial = 0;
		inverse_video = 0;
		alt_part = 0;

		part_eff = part;
		if (part == 4 || part == 1) begin
			//part_eff = frame_t >> 9;
			part_eff = frame_t >> 8;
			if (part == 1 && part_eff == 5) part_eff[2] = 0;
			alt_part = 1;
		end

		case (part_eff)
			0: palette = 0;
			1: palette = 0;
			2: palette = 1;
			3: palette = 0;
			4: palette = 1;
			5: begin
				palette = 2;
				if (alt_part) palette = 0;
			end
			6: palette = 0;
			7: palette = 1;
		endcase

		if (part == 1) begin
			if (pattern != 0 || measure == 3) lock_dx2_en = 1;
			if (pattern != 1) lock_dx2_partial = 1;
		end
		if (part == 4) begin
			inverse_video = (pattern == 0) && measure[0];
		end

		if (lock_dx2_en) begin
			if (!(lock_dx2_partial && in_gap)) begin
				palette = 2;
			end else begin
				palette = 0;
				if (pattern[1]) palette = !measure[1];
			end
		end
	end


	always_comb begin
		rgb_out = 'X;
		case (palette)
			0: case (used_value)
				// blue
				0: rgb_out = 6'b000001;
				1: rgb_out = 6'b000010;
				2: rgb_out = 6'b000110;
				3: rgb_out = 6'b101011;
				default: rgb_out = 'X;
			endcase
			1: case (used_value)
				// blue -> green
				0: rgb_out = 6'b000010;
				1: rgb_out = 6'b000110;
				2: rgb_out = 6'b011010;
				3: rgb_out = 6'b011110;
				//4: rgb_out = 6'b101110;
				default: rgb_out = 'X;
			endcase
			2: case (used_value)
				// purple -> yellow
				0: rgb_out = 6'b010001;
				1: rgb_out = 6'b100101;
				2: rgb_out = 6'b111001;
				3: rgb_out = 6'b111110;
				default: rgb_out = 'X;
			endcase
			default: rgb_out = 'X;
		endcase
		if (!vpwm_level || !active) rgb_out = 0;
	end

/*
	//wire [1:0] grey = {vpwm_level, pwm_out};
	wire [1:0] grey = {vpwm_level, vpwm_level};
	logic [1:0] r, g, b;

	//assign rgb_out = pwm_out ? '1 : 0;

	always_comb begin
		rgb_out = {grey, grey, grey};
		//r = vpwm_level + pwm_out;
		//g = {vpwm_level, 1'b0};
		//b = {pwm_out, vpwm_level};
		//rgb_out = {r, g, b};
		if (!active) rgb_out = '0;
	end
*/
endmodule : vga_skeleton
