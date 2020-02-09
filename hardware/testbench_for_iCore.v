/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.01.01
 *	Description: Test_bench
 */
`timescale 1 ns / 1 ps
/**	Please toggle following comment (i.e., `define MODELSIM) if you use 
 ** ModelSim 
 **/
// `define MODELSIM

module test_for_icore();
	reg clk = 1;
	reg resetn = 0;
	
	/** clk */
	always #5 clk = ~clk;
	/** reset */
	initial begin
		repeat (100) @(posedge clk);
		resetn <= 1;
	end
`ifdef MODELSIM	
	reg [1023:0] firmware_file;
	initial begin
		if (!$value$plusargs("firmware=%s", firmware_file))
			firmware_file = "firmware.hex";
		$readmemh(firmware_file, genData.memory);
	end
`endif

	wire 		data_out_valid, data_in_valid_temp;
	wire[133:0]	data_out, data_in_temp;
	reg 		data_in_valid;
	reg [133:0]	data_in;

um UM(
	.clk(clk),
	.rst_n(resetn),
	.um_timestamp(),
	.pktin_data_wr(data_in_valid),
	.pktin_data(data_in),
	.pktin_data_valid(),
	.pktin_data_valid_wr(),
	.pktin_ready(),
	.pktout_data_wr(data_out_valid),
	.pktout_data(data_out),
	.pktout_data_valid(),
	.pktout_data_valid_wr(),
	.pktout_ready(1'b1)
);

gen_data genData(
	.clk(clk),
	.resetn(resetn),

	.data_in_valid(data_in_valid_temp),
	.data_in(data_in_temp),
	.data_out_valid(data_out_valid),
	.data_out(data_out)
);


	reg [31:0]	count;

always @(posedge clk or negedge resetn) begin
	if (!resetn) begin
		// reset
		data_in_valid <= 1'b0;
		data_in <= 134'b0;
		count <= 32'b0;
	end
	else begin
		count <= count + 32'd1;
		if(count[12] == 1'b1) begin
			case(count[2:0])
				3'd0: begin
					data_in_valid <= 1'b1;
					data_in <= {2'b01,4'b0,128'b0};
				end
				3'd1: begin
					data_in_valid <= 1'b1;
					data_in <= {2'b11,4'b0,128'b0};
				end
				3'd2: begin
					data_in_valid <= 1'b1;
					data_in <= {2'b11,4'b0,48'h8c16_4549_2501,48'h8c16_4549_25ac,32'h08004500};
				end
				3'd3: begin
					data_in_valid <= 1'b1;
					data_in <= {2'b11,4'b0,48'h002c_0000_4000,48'h4006_863e_cac5,32'h0f82cac5};
				end
				3'd4: begin
					data_in_valid <= 1'b1;
					data_in <= {2'b11,4'b0,48'h0f81_1389_6001,48'hd332_7179_5602,32'h6cbf6012};
				end
				3'd5: begin
					data_in_valid <= 1'b1;
					data_in <= {2'b10,4'b0,48'hfaf0_b4ac_0000,
						48'h0204_05b4_0000, 32'b0};
				end
				3'd6: begin
					data_in_valid <= 1'b0;
					count <= count;
				end
			endcase
		end
		else begin
			data_in <= data_in_temp;
			data_in_valid <= data_in_valid_temp;
		end
	end
end

endmodule

