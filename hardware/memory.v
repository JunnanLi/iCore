/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.01.01
 *	Description: This module is used to store instruction, i.e., itcm,  
 *	 and data, i.e., dtcm. And we use "conf_sel" to distinguish 
 *	 configuring or running mode.
 */

`timescale 1 ns / 1 ps

/**	Please toggle following comment (i.e., `define FPGA_ALTERA) if you 
 **	 use an Alater (Intel) FPGA
 **/
// `define FPGA_ALTERA

module mem_instr(
	input 					clk,
	input 					resetn,
	// interface for cpu
	input 					mem_rinst,		
	input 			[31:0]	mem_rinst_addr,
	output	wire	[31:0]	mem_rdata_instr,
	// interface for configuration
	input					conf_rden,		
	input					conf_wren,
	input			[31:0]	conf_addr,
	input			[31:0]	conf_wdata,
	output	wire 	[31:0]	conf_rdata
);

`ifdef FPGA_ALTERA
	ram sram_for_instr(
		.address_a(mem_rinst_addr[13:0]),
		.address_b(conf_addr[13:0]),
		.clock(clk),
		.data_a(32'b0),
		.data_b(conf_wdata),
		.rden_a(mem_rinst),
		.rden_b(conf_rden),
		.wren_a(1'b0),
		.wren_b(conf_wren),
		.q_a(mem_rdata_instr),
		.q_b(conf_rdata));	
	defparam	
		sram_for_instr.width 	= 32,
		sram_for_instr.depth	= 14,
		sram_for_instr.words	= 16384;
`else
	ram_32_16384 sram_for_instr(
		.clka(clk),
		.wea(1'b0),
		.addra(mem_rinst_addr[13:0]),
		.dina(32'b0),
		.douta(mem_rdata_instr),
		.clkb(clk),
		.web(conf_wren),
		.addrb(conf_addr[13:0]),
		.dinb(conf_wdata),
		.doutb(conf_rdata)
	);
`endif	
endmodule



module mem_data(
	input 					clk,
	input 					resetn,
	// interface for cpu
	input 					mem_wren,			
	input 					mem_rden,
	input 			[31:0]	mem_addr,
	input 			[3:0]	mem_wstrb,
	input 			[31:0]	mem_wdata,
	output	wire	[31:0]	mem_rdata,
	output	reg 			ready,
	// interface for configuration
	input					conf_sel,		
	input					conf_rden,
	input					conf_wren,
	input			[31:0]	conf_addr,
	input			[31:0]	conf_wdata,
	output	wire 	[31:0]	conf_rdata,
	// for cpu writing 8-32b data and rewrite itcm;
	// output	reg				wren_conf,
	// output	reg		[31:0]	addr_conf,
	// output	reg		[31:0]	data_conf,
	
	// interface for outputing "print"
	output	reg				print_valid,	
	output	reg		[7:0]	print_value
);
	// selete one ram for writing;
	wire 			[3:0]	wren_mem;
	

	// mux of configuration or cpu writing
	assign wren_mem[0] = mem_wstrb[0]? mem_wren: 1'b0;
	assign wren_mem[1] = mem_wstrb[1]? mem_wren: 1'b0;
	assign wren_mem[2] = mem_wstrb[2]? mem_wren: 1'b0;
	assign wren_mem[3] = mem_wstrb[3]? mem_wren: 1'b0;

	genvar i_ram;
	generate
		for (i_ram = 0; i_ram < 4; i_ram = i_ram+1) begin: ram_data
		`ifdef FPGA_ALTERA
			ram sram_for_data(
				.address_a(conf_addr[13:0]),
				.address_b(mem_addr[13:0]),
				.clock(clk),
				.data_a(conf_wdata[i_ram*8+7:i_ram*8]),
				.data_b(mem_wdata[i_ram*8+7:i_ram*8]),
				.rden_a(conf_rden),
				.rden_b(mem_rden),
				.wren_a(conf_wren),
				.wren_b(wren_mem[i_ram]),
				.q_a(conf_rdata[i_ram*8+7:i_ram*8]),
				.q_b(mem_rdata[i_ram*8+7:i_ram*8]));
			defparam	
				sram_for_data.width = 8,
				sram_for_data.depth	= 14,
				sram_for_data.words	= 16384;
		`else	
			ram_8_16384 sram_for_data(
				.clka(clk),
				.wea(conf_wren),
				.addra(conf_addr[13:0]),
				.dina(conf_wdata[i_ram*8+7:i_ram*8]),
				.douta(conf_rdata[i_ram*8+7:i_ram*8]),
				.clkb(clk),
				.web(wren_mem[i_ram]),
				.addrb(mem_addr[13:0]),
				.dinb(mem_wdata[i_ram*8+7:i_ram*8]),
				.doutb(mem_rdata[i_ram*8+7:i_ram*8])
			);
		`endif
	end
	endgenerate

	

	integer i;
	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			print_value <= 8'b0;
			print_valid <= 1'b0;
		end
		else begin
			if(mem_wren == 1'b1 && mem_addr == 32'h4000000) begin
				print_valid <= 1'b1;
				print_value <= mem_wdata[7:0];
				$write("%c", mem_wdata[7:0]);
				$fflush();
			end
			else begin
				print_valid <= 1'b0;
			end
		end
	end


endmodule




// module mem_data(
// 	input 				clk,
// 	input 				resetn,
// 	// interface for cpu
// 	input 				mem_wren,			
// 	input 				mem_rden,
// 	input 		[31:0]	mem_addr,
// 	input 		[3:0]	mem_wstrb,
// 	input 		[31:0]	mem_wdata,
// 	output	wire[31:0]	mem_rdata,
// 	output	reg 		ready,
// 	// interface for configuration
// 	input					conf_sel,		
// 	input					conf_rden,
// 	input					conf_wren,
// 	input			[31:0]	conf_addr,
// 	input			[31:0]	conf_wdata,
// 	output	wire 	[31:0]	conf_rdata,
// 	// for cpu writing 8-32b data and rewrite itcm;
// 	// output	reg				wren_conf,
// 	// output	reg		[31:0]	addr_conf,
// 	// output	reg		[31:0]	data_conf,
	
// 	// interface for outputing "print"
// 	output	reg				print_valid,	
// 	output	reg		[7:0]	print_value
// );
// 	// mux of configuration or cpu writing
// 	wire 	[31:0]	addr_a;				
// 	wire 	[31:0]	data_a;
// 	wire 			wren_a;
// 	// for cpu writing 8-32b data
// 	reg				wren_conf;
// 	reg		[31:0]	addr_conf;
// 	reg		[31:0]	data_conf;


// 	reg 			mem_wren_temp[2:0], mem_rden_temp[2:0];
// 	reg 	[31:0]	mem_addr_temp[2:0];
// 	reg 	[31:0]	mem_wdata_temp[2:0];
// 	reg 	[3:0]	mem_wstrb_temp[2:0];
// 	reg		[32:0]	mem_ctx[1:0];

// 	// mux of configuration or cpu writing
// 	assign addr_a = conf_sel? conf_addr: addr_conf;
// 	assign data_a = conf_sel? conf_wdata: data_conf;
// 	assign wren_a = conf_sel? conf_wren: wren_conf;

// `ifdef FPGA_ALTERA
// 	ram sram_for_data(
// 		.address_a(addr_a[13:0]),
// 		.address_b(mem_addr[13:0]),
// 		.clock(clk),
// 		.data_a(data_a),
// 		.data_b(32'b0),
// 		.rden_a(conf_rden&conf_sel),
// 		.rden_b(mem_rden|mem_wren),
// 		.wren_a(wren_a),
// 		.wren_b(1'b0),
// 		.q_a(conf_rdata),
// 		.q_b(mem_rdata));
// 	defparam	
// 		sram_for_data.width = 32,
// 		sram_for_data.depth	= 14,
// 		sram_for_data.words	= 16384;
// `else	
// 	ram_32_16384 sram_for_data(
// 		.clka(clk),
// 		.wea(wren_a),
// 		.addra(addr_a[13:0]),
// 		.dina(data_a),
// 		.douta(conf_rdata),
// 		.clkb(clk),
// 		.web(1'b0),
// 		.addrb(mem_addr[13:0]),
// 		.dinb(32'b0),
// 		.doutb(mem_rdata)
// 	);
// `endif

	

// 	always @(posedge clk or negedge resetn) begin
// 		if (!resetn) begin
// 			// reset
// 			mem_ctx[0]	<= 33'b0;
// 			mem_ctx[1]	<= 33'b0;
// 		end
// 		else begin
// 			if((mem_wren|mem_rden) && wren_conf && 
// 				(mem_addr[13:0] == addr_conf[13:0])) 
// 					mem_ctx[0] <= {1'b1,data_conf};
// 			else
// 					mem_ctx[0] <= 33'b0;

// 			if((mem_wren_temp[0]|mem_rden_temp[0]) && wren_conf && 
// 				(mem_addr_temp[0][13:0] == addr_conf[13:0])) 
// 					mem_ctx[1] <= {1'b1,data_conf};
// 			else
// 					mem_ctx[1] <= mem_ctx[0];
// 		end
// 	end

// 	integer i;
// 	always @(posedge clk or negedge resetn) begin
// 		if (!resetn) begin
// 			// reset
// 			addr_conf 	<= 32'b0;
// 			wren_conf 	<= 1'b0;
// 			ready 		<= 1'b0;
// 			print_value <= 8'b0;
// 			print_valid <= 1'b0;
// 		end
// 		else begin
// 			mem_wstrb_temp[0] <= mem_wstrb;
// 			mem_wdata_temp[0] <= mem_wdata;
// 			mem_addr_temp[0]  <= mem_addr;
// 			mem_wren_temp[0]  <= mem_wren;
// 			mem_rden_temp[0]  <= mem_rden;
// 			for(i=1; i<3; i=i+1) begin
// 				mem_wstrb_temp[i] <= mem_wstrb_temp[i-1];
// 				mem_wdata_temp[i] <= mem_wdata_temp[i-1];
// 				mem_addr_temp[i]  <= mem_addr_temp[i-1];
// 				mem_wren_temp[i]  <= mem_wren_temp[i-1];
// 				mem_rden_temp[i]  <= mem_rden_temp[i-1];
// 			end

// 			print_valid <= 1'b0;

// 			if(mem_wren_temp[1]==1'b1) begin
// 				// $display("mem_wren, mem_wdata is %08x, mem_addr is %08x, mem_wstrb is %x", mem_wdata_temp[1], mem_addr_temp[1], mem_wstrb_temp[1]);
// 				if(mem_addr_temp[1] < 32'd16384) begin
// 					/** write mem */
// 					wren_conf <= 1'b1;
// 					addr_conf <= mem_addr_temp[1];

// 					// Memmory hazard
// 					if(wren_conf && (mem_addr_temp[1][13:0] == addr_conf[13:0])) 
// 						data_conf <= data_conf;
// 					else if(mem_ctx[1][32] == 1'b1)
// 						data_conf <= mem_ctx[1][31:0];
// 					else
// 						data_conf <= mem_rdata;

// 					if (mem_wstrb_temp[1][0]) 	data_conf[ 7: 0] <= mem_wdata_temp[1][ 7: 0];
// 					if (mem_wstrb_temp[1][1]) 	data_conf[15: 8] <= mem_wdata_temp[1][15: 8];
// 					if (mem_wstrb_temp[1][2]) 	data_conf[23:16] <= mem_wdata_temp[1][23:16];
// 					if (mem_wstrb_temp[1][3]) 	data_conf[31:24] <= mem_wdata_temp[1][31:24];
// 				end
// 				else begin
// 					/** display*/
// 					wren_conf <= 1'b0;
// 					if(mem_addr_temp[1] == 32'h4000000) begin
// 						print_valid <= 1'b1;
// 						print_value <= mem_wdata_temp[1][7:0];
// 						$write("%c", mem_wdata_temp[1][7:0]);
// 						$fflush();
// 					end
// 					// else if(mem_addr_temp[1][27]  == 1'b1) begin
// 					// 	$display("test passed");
// 					// end
// 					// else begin
// 					// 	$display("out of bound, addr is %08x", mem_addr_temp[1]);
// 					// 	$finish;
// 					// end
// 				end
// 			end
// 			else begin
// 				wren_conf <= 1'b0;
// 			end

// 		end
// 	end


// endmodule

