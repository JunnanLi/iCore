/*
 *  TuMan32 -- A Small but pipelined RISC-V (RV32I) Processor Core
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>
 *
 *  Permission to use, copy, modify, and/or distribute this code for any purpose with or
 *   without fee is hereby granted, provided that the above copyright notice and this 
 *   permission notice appear in all copies.
 *
 *	Function description: This module is the top module.
 */

 `timescale 1 ns / 1 ps

module TuMan32_top(
	input					clk,
	input 					resetn,
	// interface for configuring itcm
	input					conf_rden_itcm,
	input					conf_wren_itcm,
	input			[31:0]	conf_addr_itcm,
	input			[31:0]	conf_wdata_itcm,
	output	wire 	[31:0]	conf_rdata_itcm,
	// interface for configuring dtcm
	input					conf_sel_dtcm,
	input					conf_rden_dtcm,
	input					conf_wren_dtcm,
	input			[31:0]	conf_addr_dtcm,
	input			[31:0]	conf_wdata_dtcm,
	output	wire 	[31:0]	conf_rdata_dtcm,
	// interface for outputing "print"
	output 	wire 			print_valid,
	output 	wire 	[7:0]	print_value,
	// interface for accessing ram in pipeline
	output	wire			mem_wren_toPipe,
	output	wire			mem_rden_toPipe,
	output	wire	[31:0]	mem_addr_toPipe,
	output	wire	[31:0]	mem_wdata_toPipe,
	input			[31:0]	mem_rdata_fromPipe
);

/** sram interface for instruction and data*/
	wire 		mem_rinst;					//	read request
	wire [31:0]	mem_rinst_addr;				//	read addr
	wire [31:0]	mem_rdata_instr;			//	instruction
	wire 		mem_wren, mem_wren_dtcm;	//	write data request
	wire 		mem_rden, mem_rden_dtcm;	//	read data request
	wire [31:0]	mem_addr, mem_addr_dtcm;	//	write/read addr
	wire [31:0]	mem_wdata, mem_wdata_dtcm;	//	write data
	wire [3:0]	mem_wstrb;					//	write wstrb
	wire [31:0]	mem_rdata, mem_rdata_dtcm;	//	data
	reg			mem_addr_tag[1:0];			//	tag;


TuMan_core TuMan32(
	.clk(clk),
	.resetn(resetn&~conf_sel_dtcm),
	.finish(),

	.mem_rinst(mem_rinst),
	.mem_rinst_addr(mem_rinst_addr),
	.mem_rdata_instr(mem_rdata_instr),

	.mem_wren(mem_wren),
	.mem_rden(mem_rden),
	.mem_addr(mem_addr),
	.mem_wdata(mem_wdata),
	.mem_wstrb(mem_wstrb),
	.mem_rdata(mem_rdata),

	.trace_valid(),
	.trace_data()
);

mem_instr ITCM(
	.clk(clk),
	.resetn(resetn),

	.mem_rinst(mem_rinst),
	.mem_rinst_addr({2'b0,mem_rinst_addr[31:2]}),
	.mem_rdata_instr(mem_rdata_instr),

	.conf_rden(conf_rden_itcm),
	.conf_wren(conf_wren_itcm),
	.conf_addr(conf_addr_itcm),
	.conf_wdata(conf_wdata_itcm),
	.conf_rdata(conf_rdata_itcm)
);

mem_data DTCM(
	.clk(clk),
	.resetn(resetn),
	.mem_wren(mem_wren_dtcm),
	.mem_rden(mem_rden_dtcm),
	.mem_addr(mem_addr_dtcm),
	.mem_wdata(mem_wdata_dtcm),
	.mem_wstrb(mem_wstrb),
	.mem_rdata(mem_rdata_dtcm),
	.ready(),

	.conf_sel(conf_sel_dtcm),
	.conf_rden(conf_rden_dtcm),
	.conf_wren(conf_wren_dtcm),
	.conf_addr(conf_addr_dtcm),
	.conf_wdata(conf_wdata_dtcm),
	.conf_rdata(conf_rdata_dtcm),

	.print_valid(print_valid),
	.print_value(print_value)
);

	assign mem_rden_toPipe = mem_rden;
	assign mem_wren_toPipe = (mem_addr[31] == 1'b1)? mem_wren : 1'b0;
	assign mem_addr_toPipe = {2'b0,mem_addr[31:2]};
	assign mem_wdata_toPipe = mem_wdata;
	
	assign mem_rden_dtcm = mem_rden;
	assign mem_wren_dtcm = (mem_addr[31] == 1'b0)? mem_wren : 1'b0;
	assign mem_addr_dtcm = {2'b0,mem_addr[31:2]};
	assign mem_wdata_dtcm = mem_wdata;
	/** mem_addr[31] == '1' is accessing RAM in pipeline*/
	assign mem_rdata = (mem_addr_tag[1] == 1'b1)? mem_rdata_fromPipe : mem_rdata_dtcm;

	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			mem_addr_tag[0]	<= 1'b0;
			mem_addr_tag[1]	<= 1'b0;
		end
		else begin
			mem_addr_tag[0]	<= mem_addr[31];
			mem_addr_tag[1]	<= mem_addr_tag[0];
		end
	end

endmodule

