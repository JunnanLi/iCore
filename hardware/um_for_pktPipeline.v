/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.01.01
 *	Description: This top module pipeline.
 */

module um_for_pktPipeline(
	input				clk,
	input				rst_n,
    
	//CPU (ARM A8) or Physical ports
	input				data_in_valid,
	input		[133:0] data_in,	// 2'b01 is head, 2'b00 is body, and 2'b10 is tail;
	
	output wire			data_out_valid,
	output wire	[133:0]	data_out,
	input				mem_wren,
	input				mem_rden,
	input		[31:0]	mem_addr,
	input		[31:0]	mem_wdata,
	output wire	[31:0]	mem_rdata
);

	/*	reg and wire */
	wire		[133:0]	data_p2m;
	wire				data_valid_p2m;

	/*	parser */
	parser parse_pkt(
		.clk(clk),
		.rst_n(rst_n),
		.data_in_valid(data_in_valid),
		.data_in(data_in),
		.data_out_valid(data_valid_p2m),
		.data_out(data_p2m)
	);


	/*	manage */
	manage manage_pkt(
		.clk(clk),
		.rst_n(rst_n),
		.data_in_valid(data_valid_p2m),
		.data_in(data_p2m),
		.data_out_valid(data_out_valid),
		.data_out(data_out),
		.mem_wren(mem_wren),
		.mem_rden(mem_rden),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_rdata(mem_rdata)
	);

	

	
endmodule    
