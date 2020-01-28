/*
 *  iCore -- A hardware packet processing pipeline integrated with a in-line RISC-V Core
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>
 *
 *  Permission to use, copy, modify, and/or distribute this code for any purpose with or
 *   without fee is hereby granted, provided that the above copyright notice and this 
 *   permission notice appear in all copies.
 *
 *	Function description: This module is used to process packets, including writing 
 *	 packets to RAM, reading packets which have been processed by CPU.
 */

/**	Please toggle following comment (i.e., `define FPGA_ALTERA) if you use an Alater
 **	 (Intel) FPGA
 **/
// `define FPGA_ALTERA

module manage(
	input 				clk,
	input 				rst_n,
	// FAST packets from CPU (ARM A8) or Physical ports, the format is according to fast 
	//	 project (www.http://www.fastswitch.org/)
	input				data_in_valid,
	input		[133:0]	data_in,				// 2'b01 is head, 2'b00 is body, 
												//	and 2'b10 is tail;
	output reg			data_out_valid,
	output reg	[133:0] data_out,
	//	interface for reading/writing RAM by CPU
	input 				mem_wren,				// write enable
	input 				mem_rden,				// read enable
	input 		[31:0]	mem_addr,				// write/read address
	input 		[31:0]	mem_wdata,				// write data
	output	reg [31:0]	mem_rdata				// read data (returned)
);
	// NUM_RAM is the number of distributed RAM, in this project is 3;
	parameter			NUM_RAM = 3;

	/**	reg and wire */
	reg			[8:0]	addr_pipe[NUM_RAM-1:0];			// ram interface for packet
	reg			[159:0]	data_pipe[NUM_RAM-1:0];
	wire		[3:0]	wren_cpu[NUM_RAM-1:0];
	reg					wren_pipe[NUM_RAM-1:0];
	reg					rden_pipe[NUM_RAM-1:0];
	wire		[127:0]	q_cpu[NUM_RAM-1:0];
	wire		[159:0]	q_pipe[NUM_RAM-1:0];

	reg			[7:0]	pointPkt_rx_ram[NUM_RAM-1:0];	// rx_point for writing packets;
	reg			[7:0]	pointPkt_tx_ram[NUM_RAM-1:0];	// tx_point for reading packets;
	reg	[NUM_RAM-1:0]	fullTag_rx, fullTag_tx;			// fullTag of rx/tx;
	reg	[NUM_RAM-1:0]	rden_tag, wren_tag;				// distinguish which RAM to rd/wr;
	reg					pktout_valid[NUM_RAM-1:0];		// pakcet out valid;
	reg			[133:0]	pktout[NUM_RAM-1:0];			// packet out, fast packet format;
	//	fifo
	reg	[NUM_RAM-1:0]	rdreq_pkt;		// fifo interface for packet waiting for writing;
	wire				empty_pkt;
	wire		[133:0]	q_pkt;

	reg			[31:0]	mem_addr_temp[1:0];		// maintaing read address accessed by CPU;
	
	//	state for writing/reading packets
	reg			[3:0]	state_ingress[NUM_RAM-1:0];
	parameter			IDLE_S		= 4'd0,
						READ_FIFO_S	= 4'd1,
						WAIT_TAIL_S	= 4'd2,
						WAIT_1_S	= 4'd3,
						WAIT_2_S	= 4'd4,
						READ_RAM_S	= 4'd5,
						SEND_TAIL_S	= 4'd6;
		
	/**	state machine for dispatching ram for writing and reading. We use fullTag_rx/tx
	 **		to identify whether current dispatched ram is full (wrting) or empty (empty).
	 **		We use wren_tag, rden_tag (3b) to dipatch ram for writing or reading.
	 **		So, the processing logic is that:
	 **		1) inilization:	wren_tag/rden_tag are 3'd1, i.e., write/read the first ram, 
	 **			while fullTag_rx/fullTag_tx is 3'd0, i.e., all are empty;
	 **		2) asigned left shift wren_tag when pointPkt_rx_ram[i] == fullTag_rx[i],  
	 **			which means current dispatched ram is full; 
	 **		3) asigned left shift rden_tag when pointPkt_tx_ram[i] == fullTag_tx[i],
	 **			which means current dispatched ram is empty;
	 **		Noting: only one action (i.e., read or write) can be executed when writing  
	 **			and reading the same RAM; writing is paused when current RAM is full and 
	 **			the next RAM is reading.
	 **/
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			/***1)*/
			rden_tag		<= 3'd1;
			wren_tag		<= 3'd1;
			fullTag_rx		<= 0;
			fullTag_tx		<= 0;
		end
		else begin
			/***2)*/
			(* full_case *)
			case (wren_tag)
				3'b1: begin
					if(pointPkt_rx_ram[0][2] != fullTag_rx[0]) begin
						if(rden_tag == 3'b10) begin
							fullTag_rx[0]	<= fullTag_rx[0];
						end
						else begin
							wren_tag 		<= 3'b10;
							fullTag_rx[0]	<= ~fullTag_rx[0];
						end
					end
					else begin
						fullTag_rx[0]		<= fullTag_rx[0];
					end
				end
				3'b10: begin
					if(pointPkt_rx_ram[1][2] != fullTag_rx[1]) begin
						if(rden_tag == 3'b100) begin
							fullTag_rx[1]	<= fullTag_rx[1];
						end
						else begin
							wren_tag 		<= 3'b100;
							fullTag_rx[1]	<= ~fullTag_rx[1];
						end
					end
					else begin
						fullTag_rx[1]		<= fullTag_rx[1];
					end
				end
				3'b100: begin
					if(pointPkt_rx_ram[2][2] != fullTag_rx[2]) begin
						if(rden_tag == 3'b1) begin
							fullTag_rx[2]	<= fullTag_rx[2];
						end
						else begin
							wren_tag 		<= 3'b1;
							fullTag_rx[2]	<= ~fullTag_rx[2];
						end
					end
					else begin
						fullTag_rx[2]		<= fullTag_rx[2];
					end
				end
			endcase
			
			/***3)*/
			(* full_case *)
			case (rden_tag)
				3'b1: begin
					if(pointPkt_tx_ram[0][2] != fullTag_tx[0]) begin
						rden_tag		<= 3'b10;
						fullTag_tx[0]	<= ~fullTag_tx[0];
					end
				end	
				3'b10: begin
					if(pointPkt_tx_ram[1][2] != fullTag_tx[1]) begin
						rden_tag		<= 3'b100;
						fullTag_tx[1]	<= ~fullTag_tx[1];
					end
				end	
				3'b100:	begin 
					if(pointPkt_tx_ram[2][2] != fullTag_tx[2]) begin
						rden_tag		<= 3'b1;
						fullTag_tx[2]	<= ~fullTag_tx[2];
					end
				end 
			endcase
		end
	end

	/** read packet fifo:
	 **		1) buffer packet;
	 **		2) read packet by one of three ram;
	 **/
`ifdef FPGA_ALTERA
	fifo pkt_buffer(
		.aclr(!rst_n),
		.clock(clk),
		.data(data_in),
		.rdreq(|rdreq_pkt),
		.wrreq(data_in_valid),
		.empty(empty_pkt),
		.full(),
		.q(q_pkt),
		.usedw()
	);
	defparam
		pkt_buffer.width = 134,
		pkt_buffer.depth = 8,
		pkt_buffer.words = 256;
`else
	fifo_134_256 pkt_buffer(
		.clk(clk),
		.srst(!rst_n),
		.din(data_in),
		.wr_en(data_in_valid),
		.rd_en(|rdreq_pkt),
		.dout(q_pkt),
		.full(),
		.empty(empty_pkt)
	);
`endif
	

	/** state machine for writing/reading packets to/from RAM:
	 **		1) read packet from fifo, and writing packet to one RAM accroding to wren_tag;
	 **		2) read packet from one ram according to rden_tag, and output packet;
	 **/
	integer i;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			// reset
			for(i=0; i<NUM_RAM; i=i+1) begin
				rdreq_pkt[i]	<= 1'b0;
				data_pipe[i]	<= 160'b0;
				addr_pipe[i]	<= 9'b0;
				wren_pipe[i]	<= 1'b0;
				rden_pipe[i]	<= 1'b0;
				
				pointPkt_rx_ram[i]	<= 8'h0;
				pointPkt_tx_ram[i]	<= 8'h0;
				pktout_valid[i]	<= 1'b0;
				pktout[i]		<= 134'b0;

				state_ingress[i]<= IDLE_S;
			end
		end
		else begin
			for(i=0; i<NUM_RAM; i=i+1) begin
				case(state_ingress[i])
					IDLE_S: begin
						pktout_valid[i]			<= 1'b0;
						wren_pipe[i]			<= 1'b0;
						/***1): reading packet when wren_tag (bitmap) is equal to current 
						 ***	ramID, fifo is not empty, other rams isn't reading fifo,
						 ***	and current RAM is not full;
						 ***/
						if(empty_pkt == 1'b0 && wren_tag[i] == 1'b1 && rdreq_pkt == 0 &&
							fullTag_rx[i] == pointPkt_rx_ram[i][2]) begin
								rdreq_pkt[i]	<= 1'b1;
								state_ingress[i]<= READ_FIFO_S;
						end
						/***2):	reading packet from RAM when rden_tag (bitmap) is equal to
						 ***	current ramID, other rams isn't outputing packets;
						 ***/
						else if(rden_tag[i] == 1'd1 && {rden_pipe[0],rden_pipe[1],
							rden_pipe[2]} == 3'd0) begin
								rden_pipe[i]		<= 1'b1;
								addr_pipe[i]		<= {pointPkt_tx_ram[i][1:0],7'b0};
								state_ingress[i]	<= WAIT_1_S;
						end
					end
					READ_FIFO_S: begin
						/***1): reading packet from fifi, and construct 160b data; 
						 ***/
						data_pipe[i] 			<= {26'b0,q_pkt};
						wren_pipe[i]			<= 1'b1;
						addr_pipe[i]			<= {pointPkt_rx_ram[i][1:0],7'b0};
						pointPkt_rx_ram[i]		<= pointPkt_rx_ram[i] + 8'd1;
						state_ingress[i]		<= WAIT_TAIL_S;
					end
					WAIT_TAIL_S: begin
						/***1): writing ram until packet tail; 
						 ***/
						addr_pipe[i]			<= addr_pipe[i] + 9'd1;
						data_pipe[i] 			<= {26'b0,q_pkt};
						if(q_pkt[133:132] == 2'b10) begin
							rdreq_pkt[i]		<= 1'b0;
							state_ingress[i] 	<= IDLE_S;
						end
						else begin
							state_ingress[i] 	<= WAIT_TAIL_S;
						end
					end
					WAIT_1_S: begin
						addr_pipe[i]			<= addr_pipe[i] + 9'd1;
						state_ingress[i]		<= WAIT_2_S;
					end
					WAIT_2_S: begin
						addr_pipe[i]			<= addr_pipe[i] + 9'd1;
						state_ingress[i]		<= READ_RAM_S;
					end
					READ_RAM_S: begin
						/***2):	check metadata[0][1], i.e., cpu_done, which means packet has
						 ***	been processed by CPU, and can be output;
						 ***/
						addr_pipe[i]			<= addr_pipe[i] + 9'd1;
						if(q_pipe[i][1] == 1'b1) begin
							pktout_valid[i]		<= 1'b1;
							pktout[i]			<= q_pipe[i][133:0];
							pointPkt_tx_ram[i]	<= pointPkt_tx_ram[i] + 8'd1;
							state_ingress[i]	<= SEND_TAIL_S;
						end
						else begin
							rden_pipe[i]		<= 1'b0;
							state_ingress[i]	<= IDLE_S;
						end
					end
					SEND_TAIL_S: begin
						/***2): outputing packet until packet tail; 
						 ***/
						addr_pipe[i]			<= addr_pipe[i] + 9'd1;
						pktout_valid[i]			<= 1'b1;
						pktout[i]				<= q_pipe[i][133:0];
						if(q_pipe[i][133:132] == 2'b10) begin							
							state_ingress[i]	<= IDLE_S;
							// clear metadata[0][1:0], i.e., cpu_done, packet_ready;
							addr_pipe[i]		<= {addr_pipe[i][8:7],7'b0};
							data_pipe[i]		<= 160'b0;
							wren_pipe[i]		<= 1'b1;
							rden_pipe[i]		<= 1'b0;
						end
						else begin
							state_ingress[i]	<= SEND_TAIL_S;
						end
					end
					default: begin
						state_ingress[i]	<= IDLE_S;
					end
				endcase
			end
		end
	end

	/**	state machine for outputing packet*/
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			data_out_valid	<= 1'b0;
			data_out		<= 134'b0;
		end
		else begin
			if(pktout_valid[0]) begin
				data_out_valid	<= 1'b1;
				data_out		<= pktout[0];
			end
			else if(pktout_valid[1]) begin
				data_out_valid	<= 1'b1;
				data_out		<= pktout[1];
			end
			else if(pktout_valid[2]) begin
				data_out_valid	<= 1'b1;
				data_out		<= pktout[2];
			end
			else begin
				data_out_valid	<= 1'b0;
			end
		end
	end

	/**	assign one wren_cpu of 12 RAMs */
	assign wren_cpu[0][0] = (mem_addr[12:11] == 2'd0 && mem_addr[1:0] == 2'd0)? mem_wren: 1'b0;
	assign wren_cpu[0][1] = (mem_addr[12:11] == 2'd0 && mem_addr[1:0] == 2'd1)? mem_wren: 1'b0;
	assign wren_cpu[0][2] = (mem_addr[12:11] == 2'd0 && mem_addr[1:0] == 2'd2)? mem_wren: 1'b0;
	assign wren_cpu[0][3] = (mem_addr[12:11] == 2'd0 && mem_addr[1:0] == 2'd3)? mem_wren: 1'b0;
	assign wren_cpu[1][0] = (mem_addr[12:11] == 2'd1 && mem_addr[1:0] == 2'd0)? mem_wren: 1'b0;
	assign wren_cpu[1][1] = (mem_addr[12:11] == 2'd1 && mem_addr[1:0] == 2'd1)? mem_wren: 1'b0;
	assign wren_cpu[1][2] = (mem_addr[12:11] == 2'd1 && mem_addr[1:0] == 2'd2)? mem_wren: 1'b0;
	assign wren_cpu[1][3] = (mem_addr[12:11] == 2'd1 && mem_addr[1:0] == 2'd3)? mem_wren: 1'b0;
	assign wren_cpu[2][0] = (mem_addr[12:11] == 2'd2 && mem_addr[1:0] == 2'd0)? mem_wren: 1'b0;
	assign wren_cpu[2][1] = (mem_addr[12:11] == 2'd2 && mem_addr[1:0] == 2'd1)? mem_wren: 1'b0;
	assign wren_cpu[2][2] = (mem_addr[12:11] == 2'd2 && mem_addr[1:0] == 2'd2)? mem_wren: 1'b0;
	assign wren_cpu[2][3] = (mem_addr[12:11] == 2'd2 && mem_addr[1:0] == 2'd3)? mem_wren: 1'b0;

	/**	assign mem_rdata from 12 RAMs */
	always @(*) begin
		case({mem_addr_temp[1][12:11],mem_addr_temp[1][1:0]})
			4'b0:	mem_rdata = q_cpu[0][127:96];
			4'b1:	mem_rdata = q_cpu[0][95:64];
			4'b10:	mem_rdata = q_cpu[0][63:32];
			4'b11:	mem_rdata = q_cpu[0][31:0];
			4'b100:	mem_rdata = q_cpu[1][127:96];
			4'b101:	mem_rdata = q_cpu[1][95:64];
			4'b110:	mem_rdata = q_cpu[1][63:32];
			4'b111:	mem_rdata = q_cpu[1][31:0];
			4'b1000:mem_rdata = q_cpu[2][127:96];
			4'b1001:mem_rdata = q_cpu[2][95:64];
			4'b1010:mem_rdata = q_cpu[2][63:32];
			4'b1011:mem_rdata = q_cpu[2][31:0];
			default:mem_rdata = 0;
		endcase
	end

	/**	state machine for maintaining address of cpu reading */
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			mem_addr_temp[0]	<= 32'b0;	// assigned at wait_1
			mem_addr_temp[1]	<= 32'b0;	// assigned at wait_2
		end
		else begin
			mem_addr_temp[0]	<= mem_addr;
			mem_addr_temp[1]	<= mem_addr_temp[0];
		end
	end

	/**	three 160b-distributed ram, i.e., 0-2, each has five 32b ram , i.e, 0-4, used
	 **	 to store one 160b data. 0 is used to store pkt[133:128]'s info, which cannot
	 **	 be accessed by CPU;
	 **/
	// data[159:128]
	genvar i_ram_0;
	generate
		for (i_ram_0=0; i_ram_0<3; i_ram_0=i_ram_0+1) begin: ram_pkt_159_128
		`ifdef FPGA_ALTERA
			ram sram_for_pkt_0(
				.address_a(9'b0),
				.address_b(addr_pipe[i_ram_0]),
				.clock(clk),
				.data_a(32'b0),
				.data_b(data_pipe[i_ram_0][159:128]),
				.rden_a(1'b0),
				.rden_b(rden_pipe[i_ram_0]),
				.wren_a(1'b0),
				.wren_b(wren_pipe[i_ram_0]),
				.q_a(),
				.q_b(q_pipe[i_ram_0][159:128]));	
			defparam	
				sram_for_pkt_0.width 	= 32,
				sram_for_pkt_0.depth	= 9,
				sram_for_pkt_0.words	= 512;
		`else
			ram_32_512 sram_for_pkt_0(
				.clka(clk),
				.wea(1'b0),
				.addra(9'b0),
				.dina(32'b0),
				.douta(),
				.clkb(clk),
				.web(wren_pipe[i_ram_0]),
				.addrb(addr_pipe[i_ram_0]),
				.dinb(data_pipe[i_ram_0][159:128]),
				.doutb(q_pipe[i_ram_0][159:128])
			);
		`endif
		end
	endgenerate
	// data[127:96]
	generate
		for (i_ram_0=0; i_ram_0<3; i_ram_0=i_ram_0+1) begin: ram_pkt_127_96
		`ifdef FPGA_ALTERA	
			ram sram_for_pkt_1(
				.address_a(mem_addr[10:2]),
				.address_b(addr_pipe[i_ram_0]),
				.clock(clk),
				.data_a(mem_wdata),
				.data_b(data_pipe[i_ram_0][127:96]),
				.rden_a(mem_rden),
				.rden_b(rden_pipe[i_ram_0]),
				.wren_a(wren_cpu[i_ram_0][0]),
				.wren_b(wren_pipe[i_ram_0]),
				.q_a(q_cpu[i_ram_0][127:96]),
				.q_b(q_pipe[i_ram_0][127:96]));	
			defparam	
				sram_for_pkt_1.width 	= 32,
				sram_for_pkt_1.depth	= 9,
				sram_for_pkt_1.words	= 512;
		`else
			ram_32_512 sram_for_pkt_1(
				.clka(clk),
				.wea(wren_cpu[i_ram_0][0]),
				.addra(mem_addr[10:2]),
				.dina(mem_wdata),
				.douta(q_cpu[i_ram_0][127:96]),
				.clkb(clk),
				.web(wren_pipe[i_ram_0]),
				.addrb(addr_pipe[i_ram_0]),
				.dinb(data_pipe[i_ram_0][127:96]),
				.doutb(q_pipe[i_ram_0][127:96])
			);
		`endif
		end
	endgenerate
	// data[95:64]
	generate
		for (i_ram_0=0; i_ram_0<3; i_ram_0=i_ram_0+1) begin: ram_pkt_95_64
		`ifdef FPGA_ALTERA	
			ram sram_for_pkt_2(
				.address_a(mem_addr[10:2]),
				.address_b(addr_pipe[i_ram_0]),
				.clock(clk),
				.data_a(mem_wdata),
				.data_b(data_pipe[i_ram_0][95:64]),
				.rden_a(mem_rden),
				.rden_b(rden_pipe[i_ram_0]),
				.wren_a(wren_cpu[i_ram_0][1]),
				.wren_b(wren_pipe[i_ram_0]),
				.q_a(q_cpu[i_ram_0][95:64]),
				.q_b(q_pipe[i_ram_0][95:64]));	
			defparam	
				sram_for_pkt_2.width 	= 32,
				sram_for_pkt_2.depth	= 9,
				sram_for_pkt_2.words	= 512;
		`else
			ram_32_512 sram_for_pkt_2(
				.clka(clk),
				.wea(wren_cpu[i_ram_0][1]),
				.addra(mem_addr[10:2]),
				.dina(mem_wdata),
				.douta(q_cpu[i_ram_0][95:64]),
				.clkb(clk),
				.web(wren_pipe[i_ram_0]),
				.addrb(addr_pipe[i_ram_0]),
				.dinb(data_pipe[i_ram_0][95:64]),
				.doutb(q_pipe[i_ram_0][95:64])
			);
		`endif
		end
	endgenerate
	// data[63:32]
	generate
		for (i_ram_0=0; i_ram_0<3; i_ram_0=i_ram_0+1) begin: ram_pkt_63_32
		`ifdef FPGA_ALTERA	
			ram sram_for_pkt_3(
				.address_a(mem_addr[10:2]),
				.address_b(addr_pipe[i_ram_0]),
				.clock(clk),
				.data_a(mem_wdata),
				.data_b(data_pipe[i_ram_0][63:32]),
				.rden_a(mem_rden),
				.rden_b(rden_pipe[i_ram_0]),
				.wren_a(wren_cpu[i_ram_0][2]),
				.wren_b(wren_pipe[i_ram_0]),
				.q_a(q_cpu[i_ram_0][63:32]),
				.q_b(q_pipe[i_ram_0][63:32]));	
				defparam	
					sram_for_pkt_3.width 	= 32,
					sram_for_pkt_3.depth	= 9,
					sram_for_pkt_3.words	= 512;
		`else
			ram_32_512 sram_for_pkt_3(
				.clka(clk),
				.wea(wren_cpu[i_ram_0][2]),
				.addra(mem_addr[10:2]),
				.dina(mem_wdata),
				.douta(q_cpu[i_ram_0][63:32]),
				.clkb(clk),
				.web(wren_pipe[i_ram_0]),
				.addrb(addr_pipe[i_ram_0]),
				.dinb(data_pipe[i_ram_0][63:32]),
				.doutb(q_pipe[i_ram_0][63:32])
			);
		`endif
		end
	endgenerate
	// data[31:0]
	generate
		for (i_ram_0=0; i_ram_0<3; i_ram_0=i_ram_0+1) begin: ram_pkt_31_0
		`ifdef FPGA_ALTERA	
			ram sram_for_pkt_4(
			.address_a(mem_addr[10:2]),
			.address_b(addr_pipe[i_ram_0]),
			.clock(clk),
			.data_a(mem_wdata),
			.data_b(data_pipe[i_ram_0][31:0]),
			.rden_a(mem_rden),
			.rden_b(rden_pipe[i_ram_0]),
			.wren_a(wren_cpu[i_ram_0][3]),
			.wren_b(wren_pipe[i_ram_0]),
			.q_a(q_cpu[i_ram_0][31:0]),
			.q_b(q_pipe[i_ram_0][31:0]));	
			defparam	
				sram_for_pkt_4.width 	= 32,
				sram_for_pkt_4.depth	= 9,
				sram_for_pkt_4.words	= 512;
		`else
			ram_32_512 sram_for_pkt_4(
				.clka(clk),
				.wea(wren_cpu[i_ram_0][3]),
				.addra(mem_addr[10:2]),
				.dina(mem_wdata),
				.douta(q_cpu[i_ram_0][31:0]),
				.clkb(clk),
				.web(wren_pipe[i_ram_0]),
				.addrb(addr_pipe[i_ram_0]),
				.dinb(data_pipe[i_ram_0][31:0]),
				.doutb(q_pipe[i_ram_0][31:0])
			);
		`endif
		end
	endgenerate




	

	

	
endmodule    