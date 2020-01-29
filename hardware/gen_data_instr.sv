/*
 *  TuMan32 -- A Small but pipelined RISC-V (RV32I) Processor Core
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>
 *
 *  Permission to use, copy, modify, and/or distribute this code for any purpose with or
 *   without fee is hereby granted, provided that the above copyright notice and this 
 *   permission notice appear in all copies.
 *
 *	Function description: This module is used to generate FAST packets to configure itcm 
 *	 and dtcm of CPU.
 */
`timescale 1 ns / 1 ps

module gen_data(
	input 					clk,
	input 					resetn,

	output	reg 			data_in_valid,
	output	reg 	[133:0]	data_in,
	input					data_out_valid,
	input			[133:0]	data_out
);
	/** regs:
	*		memory[64KB] used to store instruction; 
	*/
	
	wire [1023:0][31:0] memory = {
		/**write_fix_instr*/
    };

	// reg 	[31:0] 	memory [0:64*1024/4-1];
	
	reg 	[13:0] 	addr_q;
    wire 	[31:0]	memory_data;
    reg 	[31:0]	addr_conf;

    reg 	[3:0]	count;

    always @* begin
    	addr_q <= 13'h3ff - addr_conf[9:0];
    end
	assign memory_data = memory[addr_q];

	reg [4:0]	state_mem;
	parameter 	IDLE_S 		= 5'd0,
				FAKE_DATA_S	= 5'd1,
				CONF_TCM_S	= 5'd2,
				CONF_TCM_1_S= 5'd3,
				CONF_TCM_2_S= 5'd4,
				CONF_SEL_1_S= 5'd5,
				CONF_SEL_2_S= 5'd6,
				READY_S		= 5'd7,
				READ_1_S	= 5'd8,
				READ_2_S	= 5'd9,
				READ_3_S	= 5'd10,
				READ_4_S	= 5'd11,
				READ_5_S	= 5'd12,
				READ_6_S	= 5'd13,
				WRITE_END_S	= 5'd14,
				WAIT_10_CLK_S= 5'd15,
				TEST_L2SW_S	= 5'd16;

	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			// reset
//			addr_q 		<= 14'h400;
			state_mem 	<= IDLE_S;

			data_in_valid	<= 1'b0;
			data_in 		<= 134'b0;
			count			<= 4'b0;
			addr_conf		<= 32'b0;
		end
		else begin
			case(state_mem)
				IDLE_S: begin
					data_in_valid 	<= 1'b1;
					data_in 		<= {2'b01,4'b0,128'b0};
					state_mem 		<= FAKE_DATA_S;
					count 			<= 4'b0;
				end
				FAKE_DATA_S: begin
					count <= count + 4'd1;
					case(count)
						4'd0: data_in <= {2'b11, 4'b0, 128'd0};
						4'd1: data_in <= {2'b11, 4'b0, 96'b0,16'h9001,16'b0};
						4'd2: data_in <= {2'b11, 4'b0, 112'd1,16'b0};
						4'd3: data_in <= {2'b11, 4'b0, 112'd2,16'b0};
						4'd4: data_in <= {2'b11, 4'b0, 112'd3,16'b0};
						4'd5: data_in <= {2'b10, 4'b0, 112'd4,16'b0};
						default: begin
						end
					endcase
					if(count == 4'd5)
						state_mem <= CONF_TCM_S;
				end
				CONF_TCM_S: begin
					data_in_valid 	<= 1'b1;
					data_in 		<= {2'b01,4'b0,128'b0};
					state_mem 		<= CONF_TCM_1_S;
					count 			<= 4'b0;
				end
				CONF_TCM_1_S: begin
					count <= count + 4'd1;
					case(count)
						4'd0: data_in <= {2'b11, 4'b0, 128'd0};
						4'd1: data_in <= {2'b11, 4'b0, 96'b0,16'h9003,16'b0};
						default: begin
						end
					endcase
					if(count == 4'd1)
						state_mem <= CONF_TCM_2_S;
					//addr_q <= 14'h3ff;
					addr_conf <= 32'b0;
				end
				CONF_TCM_2_S: begin
					addr_conf 	<= addr_conf + 32'd1;
					//addr_q 		<= addr_q - 14'd1;
					data_in[131:0] <= {4'b0, 48'd0, memory_data, addr_conf,16'b0};
					if(addr_conf == 32'd1023) begin
						state_mem <= READ_1_S;
						data_in[133:132] <= {2'b10};
					end
					else begin
						state_mem <= CONF_TCM_2_S;
						data_in[133:132] <= {2'b11};
					end
				end
				CONF_SEL_1_S: begin
					data_in_valid 	<= 1'b1;
					data_in 		<= {2'b01,4'b0,128'b0};
					state_mem 		<= CONF_SEL_2_S;
					count 			<= 4'b0;
				end
				CONF_SEL_2_S: begin
					count <= count + 4'd1;
					case(count)
						4'd0: data_in <= {2'b11, 4'b0, 128'd0};
						4'd1: data_in <= {2'b11, 4'b0, 96'b0,16'h9001,16'b0};
						4'd2: data_in <= {2'b11, 4'b0, 128'd0};
						4'd3: data_in <= {2'b11, 4'b0, 128'd1};
						4'd4: data_in <= {2'b11, 4'b0, 128'd2};
						4'd5: data_in <= {2'b10, 4'b0, 128'd3};
						default: begin
						end
					endcase
					if(count == 4'd5) begin
						count		<= 4'd0;
						state_mem 	<= WAIT_10_CLK_S;
					end
				end
				READ_1_S: begin
					data_in_valid 	<= 1'b1;
					data_in 		<= {2'b01,4'b0,128'b0};
					state_mem 		<= READ_2_S;
					count 			<= 4'b0;
				end
				READ_2_S: begin
					count <= count + 4'd1;
					case(count)
						4'd0: data_in <= {2'b11, 4'b0, 128'd0};
						4'd1: data_in <= {2'b11, 4'b0, 96'b0,16'h9002,16'b0};
						4'd2: data_in <= {2'b11, 4'b0, 128'd1};
						4'd3: data_in <= {2'b11, 4'b0, 128'd2};
						4'd4: data_in <= {2'b11, 4'b0, 128'd3};
						4'd5: data_in <= {2'b10, 4'b0, 128'd4};
						default: begin
						end
					endcase
					if(count == 4'd5)
						state_mem <= READ_3_S;
				end
				READ_3_S: begin
					data_in_valid 	<= 1'b1;
					data_in 		<= {2'b01,4'b0,128'b0};
					state_mem 		<= READ_4_S;
					count 			<= 4'b0;
				end
				READ_4_S: begin
					count <= count + 4'd1;
					case(count)
						4'd0: data_in <= {2'b11, 4'b0, 128'd0};
						4'd1: data_in <= {2'b11, 4'b0, 96'b0,16'h9004,16'b0};
						4'd2: data_in <= {2'b11, 4'b0, 112'd128,16'b0};
						4'd3: data_in <= {2'b11, 4'b0, 128'd2};
						4'd4: data_in <= {2'b11, 4'b0, 128'd3};
						4'd5: data_in <= {2'b10, 4'b0, 128'd4};
						default: begin
						end
					endcase
					if(count == 4'd5)
						state_mem <= READ_5_S;
				end
				READ_5_S: begin
					data_in_valid 	<= 1'b1;
					data_in 		<= {2'b01,4'b0,128'b0};
					state_mem 		<= READ_6_S;
					count 			<= 4'b0;
				end
				READ_6_S: begin
					count <= count + 4'd1;
					case(count)
						4'd0: data_in <= {2'b11, 4'b0, 128'd0};
						4'd1: data_in <= {2'b11, 4'b0, 96'b0,16'h9004,16'b0};
						4'd2: data_in <= {2'b11, 4'b0, 112'd129,16'b0};
						4'd3: data_in <= {2'b11, 4'b0, 128'd2};
						4'd4: data_in <= {2'b11, 4'b0, 128'd3};
						4'd5: data_in <= {2'b10, 4'b0, 128'd4};
						default: begin
						end
					endcase
					if(count == 4'd5)
						state_mem <= CONF_SEL_1_S;
				end
				WAIT_10_CLK_S: begin
					data_in_valid		<= 1'b0;
					count 				<= count + 4'd1;
					if(count == 4'd10) begin
						count 			<= 4'd0;
						data_in_valid 	<= 1'b1;
						data_in 		<= {2'b01,4'b0,128'b0};
						state_mem		<= TEST_L2SW_S;
					end
					else 
						state_mem		<= WAIT_10_CLK_S;
				end
				TEST_L2SW_S: begin
					count <= count + 4'd1;
					case(count)
						4'd0: data_in <= {2'b11, 4'b0, 128'd0};
						4'd1: data_in <= {2'b11, 4'b0, 96'b0,16'h9010,16'b0};
						4'd2: data_in <= {2'b11, 4'b0, 128'd0};
						4'd3: data_in <= {2'b11, 4'b0, 128'd1};
						4'd4: data_in <= {2'b11, 4'b0, 128'd2};
						4'd5: data_in <= {2'b10, 4'b0, 128'd3};
						default: begin
						end
					endcase
					if(count == 4'd5) begin
						state_mem 	<= READY_S;
					end
				end
				READY_S: begin
					data_in_valid <= 1'b0;
					state_mem <= READY_S;
				end
				default: begin
					state_mem <= IDLE_S;
				end
			endcase
		end
	end


endmodule