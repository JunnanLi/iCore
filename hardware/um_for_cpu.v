/*
 *  iCore -- A hardware packet processing pipeline integrated with a in-line RISC-V Core
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>
 *
 *  Permission to use, copy, modify, and/or distribute this code for any purpose with or
 *   without fee is hereby granted, provided that the above copyright notice and this 
 *   permission notice appear in all copies.
 *
 *	Function description: This module is used to connect TuMan_top and configuration.
 */

`define PLATFORM_RELATED_LOGIC

module um_for_cpu(
	input				clk,
	input				rst_n,
    
	// FAST packets from CPU (ARM A8) or Physical ports, the format is according to fast 
	//	 project (www.http://www.fastswitch.org/)
	input				data_in_valid,
	input		[133:0] data_in,	// 2'b01 is head, 2'b00 is body, and 2'b10 is tail;
	
	output wire			data_out_valid,
	output wire	[133:0] data_out,
	output wire			mem_wren,
	output wire			mem_rden,
	output wire	[31:0]	mem_addr,
	output wire	[31:0]	mem_wdata,
	input		[31:0]	mem_rdata,
	output wire			cpu_ready
);

	/**	TODO:*/

	wire 		conf_rden_itcm, conf_wren_itcm, conf_rden_dtcm, conf_wren_dtcm;
	wire [31:0]	conf_addr_itcm, conf_wdata_itcm, conf_rdata_itcm;
	wire [31:0]	conf_addr_dtcm, conf_wdata_dtcm, conf_rdata_dtcm;
	wire 		conf_sel_dtcm;
	wire 		print_valid;
	wire [7:0]	print_value;
	
	assign cpu_ready= ~conf_sel_dtcm;

	TuMan32_top tm(
		.clk(clk),
		.resetn(rst_n),

		.conf_rden_itcm(conf_rden_itcm),
		.conf_wren_itcm(conf_wren_itcm),
		.conf_addr_itcm(conf_addr_itcm),
		.conf_wdata_itcm(conf_wdata_itcm),
		.conf_rdata_itcm(conf_rdata_itcm),

		.conf_sel_dtcm(conf_sel_dtcm),
		.conf_rden_dtcm(conf_rden_dtcm),
		.conf_wren_dtcm(conf_wren_dtcm),
		.conf_addr_dtcm(conf_addr_dtcm),
		.conf_wdata_dtcm(conf_wdata_dtcm),
		.conf_rdata_dtcm(conf_rdata_dtcm),

		.print_valid(print_valid),
		.print_value(print_value),

		.mem_wren_toPipe(mem_wren),
		.mem_rden_toPipe(mem_rden),
		.mem_addr_toPipe(mem_addr),
		.mem_wdata_toPipe(mem_wdata),
		.mem_rdata_fromPipe(mem_rdata)
	);

	conf_mem confMem(
		.clk(clk),
		.resetn(rst_n),

		.data_in_valid(data_in_valid),
		.data_in(data_in),
		.data_out_valid(data_out_valid),
		.data_out(data_out),

		.conf_rden_itcm(conf_rden_itcm),
		.conf_wren_itcm(conf_wren_itcm),
		.conf_addr_itcm(conf_addr_itcm),
		.conf_wdata_itcm(conf_wdata_itcm),
		.conf_rdata_itcm(conf_rdata_itcm),

		.conf_sel_dtcm(conf_sel_dtcm),
		.conf_rden_dtcm(conf_rden_dtcm),
		.conf_wren_dtcm(conf_wren_dtcm),
		.conf_addr_dtcm(conf_addr_dtcm),
		.conf_wdata_dtcm(conf_wdata_dtcm),
		.conf_rdata_dtcm(conf_rdata_dtcm),

		.print_valid(print_valid),
		.print_value(print_value)
	);



	
endmodule    