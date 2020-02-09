/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.01.01
 *	Description: This module is used to process packets, including writing 
 *	 packets to RAM, reading packets which have been processed by CPU.
 */

/**	Please toggle following comment (i.e., `define FPGA_ALTERA) if you use 
 **	 an Alater (Intel) FPGA
 **/
// `define FPGA_ALTERA

module manage(
	input 				clk,
	input 				rst_n,
	// FAST packets from CPU (ARM A8) or Physical ports, the format is 
	//	 according to fast project (www.http://www.fastswitch.org/)
	input				data_in_valid,
	input		[133:0]	data_in,			// 2'b01 is head, 2'b00 is body, 
											//	and 2'b10 is tail;
	output reg			data_out_valid,
	output reg	[133:0] data_out,
	//	interface for reading/writing RAM by CPU
	input 				mem_wren,			// write enable
	input 				mem_rden,			// read enable
	input 		[31:0]	mem_addr,			// write/read address
	input 		[31:0]	mem_wdata,			// write data
	output	reg [31:0]	mem_rdata			// read data (returned)
);
	
	/**	reg and wire */
	(* mark_debug = "true" *)reg		[8:0]	addr_pipe;	// ram interface for packet;
	reg			[159:0]	data_pipe;
	(* mark_debug = "true" *)wire		[4:0]	wren_cpu;
	(* mark_debug = "true" *)reg				wren_pipe;
	(* mark_debug = "true" *)reg				rden_pipe;
	(* mark_debug = "true" *)wire		[159:0]	q_pipe,q_cpu;

	//	BIG FIFO used to store packet;
	reg					rdreq_pkt;		// fifo interface for packet waiting for writing;
	wire				empty_pkt;
	wire		[133:0]	q_pkt;
	wire		[8:0]	usedw_pkt;
	reg					wrreq_pkt;
	reg			[133:0]	data_pkt;

	reg			[1:0]	mem_addr_temp[1:0];		// maintaing read address accessed by CPU;
	(* dont_touch = "true" *)reg		[15:0]	pkt_length;
	
	//	state for writing/reading packets
	(* dont_touch = "true" *)reg		[3:0]	state_ingress, state_proc;
	parameter			IDLE_S		= 4'd0,
						WAIT_1_S	= 4'd1,
						WAIT_2_S	= 4'd2,
						READ_RAM_S	= 4'd3,
						SEND_TAIL_PIPE_S= 4'd4,
						SEND_TAIL_CPU_S	= 4'd5,
						READ_FIFO_S	= 4'd6,
						WAIT_TAIL_S	= 4'd7;

	/**	state machine for inputing packets to fifo*/
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			// reset
			data_pkt		<= 134'b0;
			wrreq_pkt		<= 1'b0;
			state_ingress	<= IDLE_S;
		end
		else begin
			data_pkt		<= data_in;
			case(state_ingress)
				IDLE_S: begin
					if(usedw_pkt[8:7] != 2'b11 && data_in[133:132] == 2'b01 && 
						data_in_valid == 1'b1) begin
							wrreq_pkt	<= 1'b1;
							state_ingress<= WAIT_TAIL_S;
					end
					else begin
						wrreq_pkt		<= 1'b0;
						state_ingress	<= IDLE_S;
					end
				end
				WAIT_TAIL_S: begin
					wrreq_pkt			<= 1'b1;
					if(data_in[133:132] == 2'b10)
						state_ingress	<= IDLE_S;
					else
						state_ingress	<= WAIT_TAIL_S;
				end
				default: begin
					state_ingress	<= IDLE_S;
				end
			endcase
		end
	end
		
	/** read packet fifo:
	 **		1) buffer packet;
	 **/
`ifdef FPGA_ALTERA
	fifo pkt_buffer(
		.aclr(!rst_n),
		.clock(clk),
		.data(data_in),
		.rdreq(rdreq_pkt),
		.wrreq(data_in_valid),
		.empty(empty_pkt),
		.full(),
		.q(q_pkt),
		.usedw(usedw_pkt)
	);
	defparam
		pkt_buffer.width = 134,
		pkt_buffer.depth = 9,
		pkt_buffer.words = 512;
`else
	fifo_134_512 pkt_buffer(
		.clk(clk),
		.srst(!rst_n),
		.din(data_in),
		.wr_en(data_in_valid),
		.rd_en(rdreq_pkt),
		.dout(q_pkt),
		.full(),
		.empty(empty_pkt),
		.data_count(usedw_pkt)
	);
`endif
	



	/** state machine for reading packets from CPU_RAM **/
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			// reset
			data_pipe		<= 160'b0;
			addr_pipe		<= 9'b0;
			wren_pipe		<= 1'b0;
			rden_pipe		<= 1'b0;
			data_out_valid	<= 1'b0;
			data_out		<= 134'b0;
			pkt_length		<= 16'b0;
			state_proc	<= IDLE_S;
		end
		else begin
			case(state_proc)
				IDLE_S: begin
					data_out_valid	<= 1'b0;

					wren_pipe		<= 1'b0;
					rden_pipe		<= 1'b1;
					addr_pipe		<= {addr_pipe[8:7]+2'd1,7'b0};
					state_proc		<= WAIT_1_S;
				end
				WAIT_1_S: begin
					addr_pipe		<= addr_pipe + 9'd1;
					state_proc		<= WAIT_2_S;
				end
				WAIT_2_S: begin
					addr_pipe		<= addr_pipe + 9'd1;
					state_proc		<= READ_RAM_S;
				end
				READ_RAM_S: begin
					/***	check metadata[0][1], i.e., cpu_done, which means packet has
					 ***	been processed by CPU, and can be output;
					 ***/
					addr_pipe			<= addr_pipe + 9'd1;
					if(q_pipe[1] == 1'b1) begin
						pkt_length		<= {4'd0,q_pipe[107:96]}-16'd16;
						data_out_valid	<= 1'b1;
						data_out		<= {2'b01,4'b0,q_pipe[127:0]};
						if(addr_pipe[8:7] == 2'b0)
							state_proc	<= SEND_TAIL_PIPE_S;
						else
							state_proc	<= SEND_TAIL_CPU_S;
					end
					else if(q_pipe[0] == 1'b1) begin
						state_proc		<= IDLE_S;
					end
					else begin
						rden_pipe		<= 1'b0;
						if(addr_pipe[8:7] == 2'b0 && empty_pkt == 1'b0) begin
							rdreq_pkt	<= 1'b1;
							state_proc	<= READ_FIFO_S;
						end
						else begin
							rdreq_pkt	<= 1'b0;
							state_proc	<= IDLE_S;
						end
					end
				end
				SEND_TAIL_PIPE_S: begin
					/*** 	outputing packet until packet tail; 
					 ***/
					addr_pipe			<= addr_pipe + 9'd1;
					data_out_valid		<= 1'b1;
					data_out			<= q_pipe[133:0];
					if(q_pipe[133:132] == 2'b10) begin			
						// clear metadata[0][1:0], i.e., cpu_done, packet_ready;
						addr_pipe		<= {addr_pipe[8:7],7'b0};
						data_pipe		<= 160'b0;
						wren_pipe		<= 1'b1;
						rden_pipe		<= 1'b0;
						if(empty_pkt == 1'b0) begin
							rdreq_pkt	<= 1'b1;
							state_proc	<= READ_FIFO_S;
						end
						else begin
							rdreq_pkt	<= 1'b0;
							state_proc	<= IDLE_S;
						end	
					end
					else begin
						state_proc		<= SEND_TAIL_PIPE_S;
					end
				end
				SEND_TAIL_CPU_S: begin
					/*** 	outputing packet until packet tail; 
					 ***/
					addr_pipe			<= addr_pipe + 9'd1;
					data_out_valid		<= 1'b1;
					data_out			<= {2'b11,4'b0,q_pipe[127:0]};
					pkt_length			<= pkt_length - 16'd16;
					if(pkt_length[15:4] == 12'b0 || pkt_length == 16'h10) begin
						data_out		<= {2'b10,(~pkt_length[3:0]+4'd1),q_pipe[127:0]};
						state_proc		<= IDLE_S;
						// clear metadata[0][1:0], i.e., cpu_done, packet_ready;
						addr_pipe		<= {addr_pipe[8:7],7'b0};
						data_pipe		<= 160'b0;
						wren_pipe		<= 1'b1;
						rden_pipe		<= 1'b0;
					end
					else begin
						state_proc	<= SEND_TAIL_CPU_S;
					end
				end
				READ_FIFO_S: begin
					data_out_valid		<= 1'b0;
					addr_pipe			<= 9'b0;
					data_pipe			<= {26'b0,q_pkt};
					wren_pipe 			<= 1'b1;
					state_proc			<= WAIT_TAIL_S;
				end
				WAIT_TAIL_S: begin
					addr_pipe			<= addr_pipe + 9'd1;
					data_pipe			<= {26'b0,q_pkt};
					wren_pipe 			<= 1'b1;
					if(q_pkt[133:132] == 2'b10) begin
						rdreq_pkt		<= 1'b0;
						state_proc		<= IDLE_S;
					end
					else begin
						rdreq_pkt		<= 1'b1;
						state_proc		<= WAIT_TAIL_S;
					end
				end
				default: begin
					state_proc			<= IDLE_S;
				end
			endcase
		end
	end

	/**	assign one wren_cpu of 12+4 RAMs */
	assign wren_cpu[3] = (mem_addr[1:0] == 2'd0)? mem_wren: 1'b0;
	assign wren_cpu[2] = (mem_addr[1:0] == 2'd1)? mem_wren: 1'b0;
	assign wren_cpu[1] = (mem_addr[1:0] == 2'd2)? mem_wren: 1'b0;
	assign wren_cpu[0] = (mem_addr[1:0] == 2'd3)? mem_wren: 1'b0;
	assign wren_cpu[4] = 0;

	/**	assign mem_rdata from 12+4 RAMs */
	always @(*) begin
		(* full_case *)
		case(mem_addr_temp[1])
			2'b11:	mem_rdata = q_cpu[31:0];
			2'b10:	mem_rdata = q_cpu[63:32];
			2'b01:	mem_rdata = q_cpu[95:64];
			2'b00:	mem_rdata = q_cpu[127:96];
		endcase
	end

	/**	state machine for maintaining address of cpu reading */
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			mem_addr_temp[0]	<= 2'b0;	// assigned at wait_1
			mem_addr_temp[1]	<= 2'b0;	// assigned at wait_2
		end
		else begin
			mem_addr_temp[0]	<= mem_addr[1:0];
			mem_addr_temp[1]	<= mem_addr_temp[0];
		end
	end

	/**	one 160b ram, divided into 4 subRAM, 0 is pktRAM, 1-3 is cpuRAM;
	 ** 160-bit RAM consists of 5 32-bit ram, 5 is used to store 
	 **	pkt[133:128]'s info, which cannot be accessed by CPU;
	 **/
	// data[159:128]
	genvar i_ram;
	generate
		for (i_ram=0; i_ram<5; i_ram=i_ram+1) begin: ram_pkt
		`ifdef FPGA_ALTERA
			ram sram_for_pkt(
				.address_a(mem_addr[10:2]),
				.address_b(addr_pipe),
				.clock(clk),
				.data_a(mem_wdata),
				.data_b(data_pipe[(i_ram*32+31):i_ram*32]),
				.rden_a(mem_rden),
				.rden_b(rden_pipe),
				.wren_a(wren_cpu[i_ram]),
				.wren_b(wren_pipe),
				.q_a(q_cpu[(i_ram*32+31):i_ram*32]),
				.q_b(q_pipe[(i_ram*32+31):i_ram*32])
			);
			defparam	
				sram_for_pkt.width 	= 32,
				sram_for_pkt.depth	= 9,
				sram_for_pkt.words	= 512;
		`else
			ram_32_512 sram_for_pkt(
				.clka(clk),
				.wea(wren_cpu[i_ram]),
				.addra(mem_addr[10:2]),
				.dina(mem_wdata),
				.douta(q_cpu[(i_ram*32+31):i_ram*32]),
				.clkb(clk),
				.web(wren_pipe),
				.addrb(addr_pipe),
				.dinb(data_pipe[(i_ram*32+31):i_ram*32]),
				.doutb(q_pipe[(i_ram*32+31):i_ram*32])
			);
		`endif
		end
	endgenerate
	

	
endmodule    
