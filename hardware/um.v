/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.01.01
 *	Description: This top module of this project.
 */

 /**	Please toggle following comment (i.e., `define FPGA_ALTERA) if you use an Alater
 **	 (Intel) FPGA
 **/
// `define FPGA_ALTERA
`define PLATFORM_RELATED_LOGIC

module um #(
	parameter    PLATFORM = "Xilinx"
)(
	input				clk,
	input		[63:0]	um_timestamp,
	input				rst_n,
    
	//CPU (ARM A8) or Physical ports
	input				pktin_data_wr,
	input		[133:0] pktin_data,	// 2'b01 is head, 2'b00 is body, and 2'b10 is tail;
	input				pktin_data_valid,
	input				pktin_data_valid_wr,
	output reg			pktin_ready,
		
	output	reg 		pktout_data_wr,
	output	reg	[133:0] pktout_data,
	output	reg			pktout_data_valid,
	output	reg			pktout_data_valid_wr,
	input				pktout_ready

`ifdef PLATFORM_RELATED_LOGIC
	//control path (have not been used)
,	input [133:0] dma2um_data,
	input dma2um_data_wr,
	output wire um2dma_ready,

	output wire [133:0] um2dma_data,
	output wire um2dma_data_wr,
	input dma2um_ready,
    	
	//to match (have not been used)
	output reg um2me_key_wr,
	output reg um2me_key_valid,
	output reg [511:0] um2match_key,
	input um2me_ready,

	//from match (have not been used)
	input me2um_id_wr,
	input [15:0] match2um_id,
	output reg um2match_gme_alful,
	
	//localbus (have not been used)
	input ctrl_valid,  
	input ctrl2um_cs_n,
	output reg um2ctrl_ack_n,
	input ctrl_cmd,
	input [31:0] ctrl_datain,
	input [31:0] ctrl_addr,
	output reg [31:0] ctrl_dataout
`endif
);

`ifdef PLATFORM_RELATED_LOGIC
	/*	have not been used in this project*/
	assign um2dma_data		= dma2um_data;
	assign um2dma_data_wr	= dma2um_data_wr;
	assign um2dma_ready		= dma2um_ready;

	/*********************************************************/
	/*	state for initializing UM2GEM*/
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
		// reset
			um2match_gme_alful <= 1'b0;
			um2me_key_wr	<= 1'b0;
			um2me_key_valid	<= 1'b0;
			um2match_key	<= 512'b0;
			um2ctrl_ack_n	<= 1'b1;
			ctrl_dataout	<= 32'b0;
		end
		else begin
		end
	end
`endif

	/*	packet in ready */
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			pktin_ready <= 1'b0;
		end
		else begin
			pktin_ready <= pktout_ready;
		end
	end


	/*	register or wire*/
	//	output packet
	wire 				pktout_data_wr_temp[1:0];
	wire 		[133:0]	pktout_data_temp[1:0];
	//	fifo
	reg					rdreq_pkt[1:0];
	wire				empty_pkt[1:0];
	wire		[133:0]	q_pkt[1:0];
	//	ram's interface for CPU
	(* dont_touch = "true" *)wire				mem_wren;
	(* dont_touch = "true" *)wire				mem_rden;
	(* dont_touch = "true" *)wire		[31:0]	mem_addr;
	(* dont_touch = "true" *)wire		[31:0]	mem_wdata;
	(* dont_touch = "true" *)wire		[31:0]	mem_rdata;
	(* dont_touch = "true" *)wire				cpu_ready;
	//	mux function
	reg		[3:0]	state_egress;
	parameter		IDLE_S		= 4'd0,
					OUTPUT_PKT_S= 4'd1;

	/*	cpu part */
	/**	cpu top module*/
	um_for_cpu UMforCPU(
		.clk(clk),
		.rst_n(rst_n),
		.data_in_valid(pktin_data_wr),
		.data_in(pktin_data),
		.data_out_valid(pktout_data_wr_temp[0]),
		.data_out(pktout_data_temp[0]),
		.mem_wren(mem_wren),
		.mem_rden(mem_rden),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_rdata(mem_rdata),
		.cpu_ready(cpu_ready)
	);

	/**	fifo used to store packet processed by CPU*/
`ifdef FPGA_ALTERA
	fifo pkt_buffer_cpu(
		.aclr(!rst_n),
		.clock(clk),
		.data(pktout_data_temp[0]),
		.rdreq(rdreq_pkt[0]),
		.wrreq(pktout_data_wr_temp[0]),
		.empty(empty_pkt[0]),
		.full(),
		.q(q_pkt[0]),
		.usedw()
	);
	defparam
		pkt_buffer_cpu.width = 134,
		pkt_buffer_cpu.depth = 9,
		pkt_buffer_cpu.words = 512;
`else
	fifo_134_512 pkt_buffer_cpu(
		.clk(clk),
		.srst(!rst_n),
		.din(pktout_data_temp[0]),
		.wr_en(pktout_data_wr_temp[0]),
		.rd_en(rdreq_pkt[0]),
		.dout(q_pkt[0]),
		.full(),
		.empty(empty_pkt[0])
	);
`endif

	/*	packet processing */
	/**	pipeline top module*/
	um_for_pktPipeline pktPipe(
		.clk(clk),
		.rst_n(rst_n&cpu_ready),
		.data_in_valid(pktin_data_wr),
		.data_in(pktin_data),
		.data_out_valid(pktout_data_wr_temp[1]),
		.data_out(pktout_data_temp[1]),
		.mem_wren(mem_wren),
		.mem_rden(mem_rden),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_rdata(mem_rdata)
	);

	/**	fifo used to store packet processed by pipeline*/
`ifdef FPGA_ALTERA
	fifo pkt_buffer_pipe(
		.aclr(!rst_n),
		.clock(clk),
		.data(pktout_data_temp[1]),
		.rdreq(rdreq_pkt[1]),
		.wrreq(pktout_data_wr_temp[1]),
		.empty(empty_pkt[1]),
		.full(),
		.q(q_pkt[1]),
		.usedw()
	);
	defparam
		pkt_buffer_pipe.width = 134,
		pkt_buffer_pipe.depth = 9,
		pkt_buffer_pipe.words = 256;
`else
	fifo_134_512 pkt_buffer_pipe(
		.clk(clk),
		.srst(!rst_n),
		.din(pktout_data_temp[1]),
		.wr_en(pktout_data_wr_temp[1]),
		.rd_en(rdreq_pkt[1]),
		.dout(q_pkt[1]),
		.full(),
		.empty(empty_pkt[1])
	);
`endif

	/*	MUX function: packet from 1)cpu and 2)pipeline */
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			pktout_data_valid_wr<= 1'b0;
			pktout_data_valid	<= 1'b0;
			pktout_data_wr		<= 1'b0;
			pktout_data			<= 134'b0;
			rdreq_pkt[0]		<= 1'b0;
			rdreq_pkt[1]		<= 1'b0;
			state_egress		<= IDLE_S;
		end
		else begin
			case(state_egress)
				IDLE_S: begin
					pktout_data_valid_wr<= 1'b0;
					pktout_data_wr 		<= 1'b0;
					// from pipeline
					if(empty_pkt[1] == 1'b0 && pktout_ready == 1'b1) begin
						rdreq_pkt[0]	<= 1'b0;
						rdreq_pkt[1]	<= 1'b1;
						state_egress	<= OUTPUT_PKT_S;
					end
					// from cpu
					else if(empty_pkt[0] == 1'b0 && pktout_ready == 1'b1) begin
						rdreq_pkt[0]	<= 1'b1;
						rdreq_pkt[1]	<= 1'b0;
						state_egress	<= OUTPUT_PKT_S;
					end
					else begin
						rdreq_pkt[0]	<= 1'b0;
						rdreq_pkt[1]	<= 1'b0;
						state_egress	<= IDLE_S;
					end

				end
				OUTPUT_PKT_S: begin
					if(rdreq_pkt[0] == 1'b1) begin
						pktout_data 			<= q_pkt[0];
						if(q_pkt[0][133:132] == 2'b10) begin
							pktout_data_valid	<= 1'b1;
							pktout_data_valid_wr<= 1'b1;
							rdreq_pkt[0]		<=1'b0;
							state_egress		<= IDLE_S;
						end
						else begin
							state_egress		<= OUTPUT_PKT_S;
						end
					end
					else begin
						pktout_data 			<= q_pkt[1];
						if(q_pkt[1][133:132] == 2'b10) begin
							pktout_data_valid	<= 1'b1;
							pktout_data_valid_wr<= 1'b1;
							rdreq_pkt[1]		<=1'b0;
							state_egress		<= IDLE_S;
						end
						else begin
							state_egress 		<= OUTPUT_PKT_S;
						end
					end
					pktout_data_wr				<= 1'b1;					
				end
				default: begin
					state_egress		<= IDLE_S;
				end
			endcase
		end
	end

	
	
endmodule    
