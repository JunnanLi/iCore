/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.01.01
 *	Description: This module is the top module.
 */
 `timescale 1 ns / 1 ps

module TuMan32_top(
	input					clk,
	input					resetn,
	// interface for configuring itcm
	input					conf_rden_itcm,
	input					conf_wren_itcm,
	input			[31:0]	conf_addr_itcm,
	input			[31:0]	conf_wdata_itcm,
	output	wire	[31:0]	conf_rdata_itcm,
	// interface for configuring dtcm
	input					conf_sel_dtcm,
	input					conf_rden_dtcm,
	input					conf_wren_dtcm,
	input			[31:0]	conf_addr_dtcm,
	input			[31:0]	conf_wdata_dtcm,
	output	wire	[31:0]	conf_rdata_dtcm,
	// interface for outputing "print"
	output	wire			print_valid,
	output	wire	[7:0]	print_value,
	// interface for accessing ram in pipeline
	output	wire			mem_wren_toPipe,
	output	wire			mem_rden_toPipe,
	output	wire	[31:0]	mem_addr_toPipe,
	output	wire	[31:0]	mem_wdata_toPipe,
	input			[31:0]	mem_rdata_fromPipe
);

/** sram interface for instruction and data*/
	(* mark_debug = "true" *)wire			mem_rinst;					//	read request
	(* mark_debug = "true" *)wire [31:0]	mem_rinst_addr;				//	read addr
	(* mark_debug = "true" *)wire [31:0]	mem_rdata_instr;			//	instruction
	wire 		mem_wren, mem_wren_dtcm;	//	write data request
	wire 		mem_rden, mem_rden_dtcm;	//	read data request
	wire [31:0]	mem_addr, mem_addr_dtcm;	//	write/read addr
	wire [31:0]	mem_wdata, mem_wdata_dtcm;	//	write data
	wire [3:0]	mem_wstrb;					//	write wstrb
	wire [31:0]	mem_rdata, mem_rdata_dtcm;	//	data
	reg			mem_addr_tag[1:0];			//	tag;
	reg			clk_counter_tag[1:0];
	reg  [31:0]	clk_counter;				//	timer;
	reg			finish_tag;					//	write 0xF0000000 with 1;

/** mux of writing by conf or dtcm*/
	// wire 		conf_wren_itcm_mux, conf_wren_d2i;
	// wire [31:0]	conf_addr_itcm_mux, conf_addr_d2i;
	// wire [31:0]	conf_wdata_itcm_mux, conf_wdata_d2i;

	// assign conf_wren_itcm_mux = conf_sel_dtcm? conf_wren_itcm: conf_wren_d2i;
	// assign conf_addr_itcm_mux = conf_sel_dtcm? conf_addr_itcm: conf_addr_d2i;
	// assign conf_wdata_itcm_mux = conf_sel_dtcm? conf_wdata_itcm: conf_wdata_d2i;

TuMan_core TuMan32(
	.clk(clk),
	.resetn(resetn&~conf_sel_dtcm&finish_tag),
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
	// .wren_conf(conf_wren_d2i),
	// .addr_conf(conf_addr_d2i),
	// .data_conf(conf_wdata_d2i),

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
	assign mem_rdata = (mem_addr_tag[1] == 1'b1)? mem_rdata_fromPipe : 
		(clk_counter_tag[1] == 1'b1)? clk_counter : mem_rdata_dtcm;

	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			mem_addr_tag[0]	<= 1'b0;
			mem_addr_tag[1]	<= 1'b0;
			
			clk_counter_tag[0]	<= 1'b0;
			clk_counter_tag[1]	<= 1'b0;
		end
		else begin
			mem_addr_tag[0]	<= mem_addr[31];
			mem_addr_tag[1]	<= mem_addr_tag[0];

			clk_counter_tag[0]	<= mem_addr[29];
			clk_counter_tag[1]	<= clk_counter_tag[0];
		end
	end

	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			finish_tag		<= 1'b1;
		end
		else begin
			if(mem_addr[31:28] == 4'hf && mem_wren == 1'b1)
				finish_tag		<= 1'b0;
			else
				finish_tag		<= finish_tag|conf_sel_dtcm;
		end
	end

	/**	for test */
	(* mark_debug = "true" *)reg [26:0]	clk_count[1:0];
	always @(posedge clk or negedge resetn) begin
		if(!resetn) begin
			clk_count[0]			<= 27'b0;
			clk_count[1]			<= 27'b0;
			clk_counter				<= 32'b0;
		end
		else begin
			if(mem_addr[29] == 1'b0)
				clk_counter			<= {5'b0,clk_count[0]};
			else
				clk_counter			<= {2'b0,clk_count[1],3'b0};

			if(conf_sel_dtcm) begin
				clk_count[0]		<= 27'b0;
				clk_count[1]		<= 27'b0;
			end	
			else begin
				clk_count[1]		<= clk_count[1] + 27'd1;
				if(clk_count[1] == 125000000) begin
					clk_count[1]	<= 27'b0;
					clk_count[0]	<= 27'b1 + clk_count[0];
				end
			end				
		end
//		if(mem_addr_toPipe == 32'h200000012 && mem_rden_toPipe)
//			$display("read addr12 clk_count: %d", clk_count);
//		else if(mem_addr_toPipe == 32'h200000011 && mem_rden_toPipe)
//            $display("read addr11 clk_count: %d", clk_count);
//		if(mem_addr_toPipe == 32'h20000003 && mem_wren_toPipe)
//			$display("write clk_count: %d", clk_count);
	end

endmodule

