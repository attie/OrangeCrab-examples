/* Copyright 2020 Gregory Davill <greg.davill@gmail.com> */

/*
 *  Blink a LED on the OrangeCrab using verilog
 */

module clk_div #(
	parameter COUNT = 1024
) (
	input clk_in,
	output clk_out
);
	reg [31:0] counter = 0;

	always @(posedge clk_in) begin
		if (counter == (COUNT - 1)) begin
			counter <= 0;
		end
		else begin
			counter <= counter + 1;
		end
	end

	assign clk_out = (counter >= (COUNT / 2));
endmodule

module latch (
	input clk_in,
	input in,
	output out
);
	reg state = 1'b1;

	always @(posedge clk_in) begin
		state <= {in};
	end

	assign out = state;
endmodule

module pwm #(
	parameter DIV_COUNT = 188
) (
	input clk_in,
	input [7:0] duty,
	output pwm
);
	wire clk_adv;

	clk_div #(
		.COUNT(DIV_COUNT)
	) cd (
		.clk_in(clk_in),
		.clk_out(clk_adv)
	);

	reg [7:0] counter = 0;

	always @(posedge clk_adv) begin
		counter <= counter + 1;
	end

	assign pwm = (counter <= duty);
endmodule

module top (
    input CLK, // 48 MHz

	output LED1, // red
	output LED2, // green
	output LED3,  // blue

	output RST_N,
	input BTN_N
);
	wire clk_adv;

	clk_div #(
		.COUNT(375_000) // 128 Hz
	) cd (
		.clk_in(CLK),
		.clk_out(clk_adv)
	);

	latch l (
		.clk_in(CLK),
		.in(BTN_N),
		.out(RST_N),
	);

	reg down = 0;
	reg [2:0] state = 0;
	reg [7:0] pwm_duty = 0;

	/* state[2:0]
	* 000   RED    _____    blue,    Magenta -> Red
	* 001   RED    green'   ____     Bed     -> Orange
	* 010   red,   GREEN    ____     Orange  -> Green
	* 011   ___    GREEN    blue'    Green   -> Cyan
	* 100   ___    green,   BLUE     Cyan    -> Blue
	* 101   red'   _____    BLUE     Blue    -> Magenta
	*/
	always @(posedge clk_adv) begin
		if (state[0] == 0) begin
			/* fade ___ down */
			if (pwm_duty == 0) begin
				state <= state + 1;
			end
			else begin
				pwm_duty <= pwm_duty - 1;
			end
		end
		else begin
			/* fade ___ up */
			if (pwm_duty == 'hFF) begin
				if (state == 'b101) begin
					state <= 0;
				end
				else begin
					state <= state + 1;
				end
			end
			else begin
				pwm_duty <= pwm_duty + 1;
			end
		end
	end

	wire pwm_out;

	pwm #(
		.DIV_COUNT(188) // 8-bit @ 1.001 Khz
	) p (
		.clk_in(CLK),
		.duty(pwm_duty),
		.pwm(pwm_out)
	);

	wire r_en;
	wire g_en;
	wire b_en;

	assign r_en = (
		((state == 'b101) && pwm_out) ||
		 (state == 'b000) ||
		 (state == 'b001) ||
		((state == 'b010) && pwm_out)
	);
	assign g_en = (
		((state == 'b001) && pwm_out) ||
		 (state == 'b010) ||
		 (state == 'b011) ||
		((state == 'b100) && pwm_out)
	);
	assign b_en = (
		((state == 'b011) && pwm_out) ||
		 (state == 'b100) ||
		 (state == 'b101) ||
		((state == 'b000) && pwm_out)
	);

	assign LED1 = ~r_en;
	assign LED2 = ~g_en;
	assign LED3 = ~b_en;

endmodule

