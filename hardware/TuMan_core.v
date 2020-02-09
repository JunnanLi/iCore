/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2020.01.01
 *  Description: Core module of TuMan
 */

`timescale 1 ns / 1 ps

// `define PRINT_TEST

/***************************************************************
 * TuMan32
 ***************************************************************/

module TuMan_core #(
	parameter [ 0:0] ENABLE_COUNTERS = 0,
	parameter [ 0:0] ENABLE_COUNTERS64 = 1,
	parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
	parameter [ 0:0] BARREL_SHIFTER = 1,
	parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
	parameter [ 0:0] TWO_CYCLE_ALU = 0,
	parameter [ 0:0] REGS_INIT_ZERO = 1,
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000
) (
	input clk, resetn,
	output reg finish,

	output reg        mem_rinst,
	output reg [31:0] mem_rinst_addr,
	input	   [31:0] mem_rdata_instr,

	output reg 	  mem_wren,
	output reg 	  mem_rden,
	output reg [31:0] mem_addr,
	output reg [31:0] mem_wdata,
	output reg [ 3:0] mem_wstrb,
	input      [31:0] mem_rdata,

	output reg        trace_valid,
	(* mark_debug = "true" *)output reg [35:0] trace_data
);


	parameter 	width_itcm 	= 32,
				IF 	= 0,
				ID 	= 1,
				RR 	= 2,
				EX 	= 3,
				RWM 	= 4,
				LR 	= 5,
				BUB_1	= 6,
				BUB_2	= 7,
				BUB_3	= 8,
				BUB_4	= 9,
				BUB_5	= 10,
				BUB_6	= 11,
				IF_B	= 1,
				ID_B 	= 2,
				RR_B 	= 4,
				EX_B 	= 8,
				RWM_B 	= 48,
				RM_B 	= 16,
				WM_B	= 32,
				LR_B 	= 64;

`ifdef PRINT_TEST
	parameter	NUM_PRINT = 10'd200;
`endif
integer i;
	localparam integer regfile_size = 32;
	localparam integer regindex_bits = 5;

	/** cpu related registers */
	(* dont_touch = "true" *)reg [31:0]	cpuregs [0:regfile_size-1];
	reg [3:0]	cpuregs_lock [0:regfile_size-1];
	/** TO TO */
	reg [63:0]	count_instr;	
	reg [63:0]	count_cycle;
	
	reg 		clk_temp[12:0];
			
	/** reg_op1, reg_op2, reg_sh are only valid after RR stage, i.e. at EX/RWM;
	*	reg_op1_2b is the last two bits of reg_op1;
	*/
	(* mark_debug = "true" *)reg [31:0]  reg_op1, reg_op2;
	reg [1:0] 	reg_op1_2b[12:0];
	reg [4:0] 	reg_sh;
	reg [31:0]	reg_op2_ex, reg_op1_ex;

	/**
	*	cpuregs_rs1, cpuregs_rs2 are only valid at RR, value assigend after ID;
	*	cpuregs_write & reg_out_r is used as bypass;
	*	cpuregs_write_ex & reg_out, cpuregs_write_rr & reg_out, load_reg_lr & 
	*		reg_out are used to update cpuregs;
	*	branch_hit_rr is for jal instruction;
	*	branch_hit_ex is for jalr instruction;
	*	load_realted_rr is for load-related (WAW ro RAW) instruction;
	*/
	(* dont_touch = "true" *)reg 		cpuregs_write[11:0], cpuregs_write_ex, cpuregs_write_rr;
	(* dont_touch = "true" *)reg [31:0] 	cpuregs_rs1;
	(* dont_touch = "true" *)reg [31:0] 	cpuregs_rs2;
	reg [regindex_bits-1:0]	decoded_rs;
	reg [31:0]	branch_pc_rr, branch_pc_ex, refetch_pc_rr, current_pc[10:0];
	(* dont_touch = "true" *)reg [31:0]	reg_out[11:0];
	(* dont_touch = "true" *)reg [31:0]	reg_out_r[11:0];
	reg 		pre_instr_finished_lr, instr_finished[11:0];
	reg 		branch_hit_rr, branch_hit_ex, load_realted_rr;
	reg 		instr_finish[4:0];
	(* mark_debug = "true" *)reg [7:0]	next_stage[11:0];
	

	// adapting to 8/16/32b read or write;
	reg [1:0] 	mem_wordsize[12:0];
	reg [31:0]	mem_rdata_word;
	
/** process of reading ro writing data */
	always @(posedge clk) begin
		reg_op2_ex <= reg_op2;
		reg_op1_ex <= reg_op1;
	end

	// write according to mem_wordsize
	always @* begin
		(* full_case *)
		case (mem_wordsize[RWM])
			0: begin
				mem_wdata = reg_op2_ex;
				mem_wstrb = 4'b1111;
			end
			1: begin
				mem_wdata = {2{reg_op2_ex[15:0]}};
				mem_wstrb = reg_op1_ex[1] ? 4'b1100 : 4'b0011;
			end
			2: begin
				mem_wdata = {4{reg_op2_ex[7:0]}};
				mem_wstrb = 4'b0001 << reg_op1_ex[1:0];
			end
		endcase
	end

	// read according to mem_wordsize
	always @* begin
		(* full_case *)
		case (mem_wordsize[BUB_5])
			0: begin
				mem_rdata_word = mem_rdata;
			end
			1: begin
				case (reg_op1_2b[BUB_5][1])
					1'b0: mem_rdata_word = {16'b0, mem_rdata[15: 0]};
					1'b1: mem_rdata_word = {16'b0, mem_rdata[31:16]};
				endcase
			end
			2: begin
				case (reg_op1_2b[BUB_5])
					2'b00: mem_rdata_word = {24'b0, mem_rdata[ 7: 0]};
					2'b01: mem_rdata_word = {24'b0, mem_rdata[15: 8]};
					2'b10: mem_rdata_word = {24'b0, mem_rdata[23:16]};
					2'b11: mem_rdata_word = {24'b0, mem_rdata[31:24]};
				endcase
			end
		endcase
	end


/** Process of decoding instructions */

	reg instr_lui[4:0], instr_auipc[4:0], instr_jal[4:0], instr_jalr[4:0];
	reg instr_beq[4:0], instr_bne[4:0], instr_blt[4:0], instr_bge[4:0], instr_bltu[4:0], instr_bgeu[4:0];
	(* mark_debug = "true" *)reg instr_lb[4:0], instr_lh[4:0], instr_lw[4:0], instr_lbu[4:0], instr_lhu[4:0], instr_sb[4:0], instr_sh[4:0], instr_sw[4:0];
	reg instr_addi[4:0], instr_slti[4:0], instr_sltiu[4:0], instr_xori[4:0], instr_ori[4:0], instr_andi[4:0], instr_slli[4:0], instr_srli[4:0], instr_srai[4:0];
	reg instr_add[4:0], instr_sub[4:0], instr_sll[4:0], instr_slt[4:0], instr_sltu[4:0], instr_xor[4:0], instr_srl[4:0], instr_sra[4:0], instr_or[4:0], instr_and[4:0];
	reg instr_rdcycle[4:0], instr_rdcycleh[4:0], instr_rdinstr[4:0], instr_rdinstrh[4:0], instr_ecall_ebreak[4:0];
	reg instr_trap;

	/**	decoded_rd, decoded_rs1, decoded_rs2, register ID, extracted from instruction;
	*	decoded_imm, the imm operated by instr;
	*	decoded_imm_j, imm of j type, extracted from instruction;
	*/
	reg [regindex_bits-1:0] decoded_rd[11:0], decoded_rs1[4:0], decoded_rs2[4:0];
	(* dont_touch = "true" *)reg [31:0] decoded_imm[11:0], decoded_imm_j;
	reg decoder_trigger;
	reg decoder_trigger_q;
	reg decoder_pseudo_trigger;
	reg decoder_pseudo_trigger_q;

	reg is_lui_auipc_jal[4:0];
	reg is_lb_lh_lw_lbu_lhu[11:0];
	reg is_slli_srli_srai[4:0];
	(* mark_debug = "true" *)reg is_jalr_addi_slti_sltiu_xori_ori_andi[4:0];
	reg is_sb_sh_sw[4:0];
	reg is_sll_srl_sra[4:0];
	reg is_lui_auipc_jal_jalr_addi_add_sub[4:0];
	reg is_slti_blt_slt[4:0];
	reg is_sltiu_bltu_sltu[4:0];
	reg is_beq_bne_blt_bge_bltu_bgeu[4:0];
	(* mark_debug = "true" *)reg is_lbu_lhu_lw[4:0];
	reg is_alu_reg_imm[4:0];
	reg is_alu_reg_reg[4:0];
	reg is_compare[4:0];
	reg [31:0]	mem_rdata_instr_reg;

	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			instr_trap <= 1'b0;
		end
		else begin
			instr_trap = !{instr_lui[ID], instr_auipc[ID], instr_jal[ID], instr_jalr[ID],
				instr_beq[ID], instr_bne[ID], instr_blt[ID], instr_bge[ID], instr_bltu[ID], instr_bgeu[ID],
				instr_lb[ID], instr_lh[ID], instr_lw[ID], instr_lbu[ID], instr_lhu[ID], instr_sb[ID], instr_sh[ID], instr_sw[ID],
				instr_addi[ID], instr_slti[ID], instr_sltiu[ID], instr_xori[ID], instr_ori[ID], instr_andi[ID], instr_slli[ID], instr_srli[ID], instr_srai[ID],
				instr_add[ID], instr_sub[ID], instr_sll[ID], instr_slt[ID], instr_sltu[ID], instr_xor[ID], instr_srl[ID], instr_sra[ID], instr_or[ID], instr_and[ID]};
		end
	end
				
	reg is_rdcycle_rdcycleh_rdinstr_rdinstrh;

	/** decode instruction, the data is mem_rdata_latched */
	always @(posedge clk) begin
		mem_rdata_instr_reg <= mem_rdata_instr;
		is_rdcycle_rdcycleh_rdinstr_rdinstrh = |{instr_rdcycle[ID], instr_rdcycleh[ID], instr_rdinstr[ID], instr_rdinstrh[ID]};

		is_lui_auipc_jal[ID] <= |{instr_lui[IF], instr_auipc[IF], instr_jal[IF]};
		is_lui_auipc_jal_jalr_addi_add_sub[RR] <= |{instr_lui[ID], instr_auipc[ID], instr_jal[ID], instr_jalr[ID], instr_addi[ID], instr_add[ID], instr_sub[ID]};
		is_slti_blt_slt[RR] <= |{instr_slti[ID], instr_blt[ID], instr_slt[ID]};
		is_sltiu_bltu_sltu[RR] <= |{instr_sltiu[ID], instr_bltu[ID], instr_sltu[ID]};
		is_lbu_lhu_lw[RR] <= |{instr_lbu[ID], instr_lhu[ID], instr_lw[ID]};
		is_compare[RR] <= |{is_beq_bne_blt_bge_bltu_bgeu[ID], instr_slti[ID], instr_slt[ID], instr_sltiu[ID], instr_sltu[ID]};

		if (clk_temp[1]) begin
			instr_lui[IF]     <= mem_rdata_instr[6:0] == 7'b0110111;
			instr_auipc[IF]   <= mem_rdata_instr[6:0] == 7'b0010111;
			instr_jal[IF]     <= mem_rdata_instr[6:0] == 7'b1101111;
			instr_jalr[IF]    <= mem_rdata_instr[6:0] == 7'b1100111 && mem_rdata_instr[14:12] == 3'b000;
			
			is_beq_bne_blt_bge_bltu_bgeu[IF] <= mem_rdata_instr[6:0] == 7'b1100011;
			is_lb_lh_lw_lbu_lhu[IF]          <= mem_rdata_instr[6:0] == 7'b0000011;
			is_sb_sh_sw[IF]                  <= mem_rdata_instr[6:0] == 7'b0100011;
			is_alu_reg_imm[IF]               <= mem_rdata_instr[6:0] == 7'b0010011;
			is_alu_reg_reg[IF]               <= mem_rdata_instr[6:0] == 7'b0110011;

			{ decoded_imm_j[31:20], decoded_imm_j[10:1], decoded_imm_j[11], decoded_imm_j[19:12], decoded_imm_j[0] } <= $signed({mem_rdata_instr[31:12], 1'b0});

			decoded_rd[IF] <= mem_rdata_instr[11:7];
			decoded_rs1[IF] <= mem_rdata_instr[19:15];
			decoded_rs2[IF] <= mem_rdata_instr[24:20];
		end

		/** decoder_pseudo_trigger is for prefetched instr, as it has been decoded before 
		*	noted that: mem_rdata_q is one clk later than mem_rdata_latched;
		*/
		if (clk_temp[2]) begin

			instr_beq[ID]   <= is_beq_bne_blt_bge_bltu_bgeu[IF] && mem_rdata_instr_reg[14:12] == 3'b000;
			instr_bne[ID]   <= is_beq_bne_blt_bge_bltu_bgeu[IF] && mem_rdata_instr_reg[14:12] == 3'b001;
			instr_blt[ID]   <= is_beq_bne_blt_bge_bltu_bgeu[IF] && mem_rdata_instr_reg[14:12] == 3'b100;
			instr_bge[ID]   <= is_beq_bne_blt_bge_bltu_bgeu[IF] && mem_rdata_instr_reg[14:12] == 3'b101;
			instr_bltu[ID]  <= is_beq_bne_blt_bge_bltu_bgeu[IF] && mem_rdata_instr_reg[14:12] == 3'b110;
			instr_bgeu[ID]  <= is_beq_bne_blt_bge_bltu_bgeu[IF] && mem_rdata_instr_reg[14:12] == 3'b111;

			instr_lb[ID]    <= is_lb_lh_lw_lbu_lhu[IF] && mem_rdata_instr_reg[14:12] == 3'b000;
			instr_lh[ID]    <= is_lb_lh_lw_lbu_lhu[IF] && mem_rdata_instr_reg[14:12] == 3'b001;
			instr_lw[ID]    <= is_lb_lh_lw_lbu_lhu[IF] && mem_rdata_instr_reg[14:12] == 3'b010;
			instr_lbu[ID]   <= is_lb_lh_lw_lbu_lhu[IF] && mem_rdata_instr_reg[14:12] == 3'b100;
			instr_lhu[ID]   <= is_lb_lh_lw_lbu_lhu[IF] && mem_rdata_instr_reg[14:12] == 3'b101;

			instr_sb[ID]    <= is_sb_sh_sw[IF] && mem_rdata_instr_reg[14:12] == 3'b000;
			instr_sh[ID]    <= is_sb_sh_sw[IF] && mem_rdata_instr_reg[14:12] == 3'b001;
			instr_sw[ID]    <= is_sb_sh_sw[IF] && mem_rdata_instr_reg[14:12] == 3'b010;

			instr_addi[ID]  <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b000;
			instr_slti[ID]  <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b010;
			instr_sltiu[ID] <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b011;
			instr_xori[ID]  <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b100;
			instr_ori[ID]   <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b110;
			instr_andi[ID]  <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b111;

			instr_slli[ID]  <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b001 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_srli[ID]  <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_srai[ID]  <= is_alu_reg_imm[IF] && mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0100000;

			instr_add[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b000 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_sub[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b000 && mem_rdata_instr_reg[31:25] == 7'b0100000;
			instr_sll[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b001 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_slt[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b010 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_sltu[ID]  <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b011 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_xor[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b100 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_srl[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_sra[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0100000;
			instr_or[ID]    <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b110 && mem_rdata_instr_reg[31:25] == 7'b0000000;
			instr_and[ID]   <= is_alu_reg_reg[IF] && mem_rdata_instr_reg[14:12] == 3'b111 && mem_rdata_instr_reg[31:25] == 7'b0000000;

			instr_rdcycle[ID]  <= ((mem_rdata_instr_reg[6:0] == 7'b1110011 && mem_rdata_instr_reg[31:12] == 'b11000000000000000010) ||
			                   (mem_rdata_instr_reg[6:0] == 7'b1110011 && mem_rdata_instr_reg[31:12] == 'b11000000000100000010)) && ENABLE_COUNTERS;
			instr_rdcycleh[ID] <= ((mem_rdata_instr_reg[6:0] == 7'b1110011 && mem_rdata_instr_reg[31:12] == 'b11001000000000000010) ||
			                   (mem_rdata_instr_reg[6:0] == 7'b1110011 && mem_rdata_instr_reg[31:12] == 'b11001000000100000010)) && ENABLE_COUNTERS && ENABLE_COUNTERS64;
			instr_rdinstr[ID]  <=  (mem_rdata_instr_reg[6:0] == 7'b1110011 && mem_rdata_instr_reg[31:12] == 'b11000000001000000010) && ENABLE_COUNTERS;
			instr_rdinstrh[ID] <=  (mem_rdata_instr_reg[6:0] == 7'b1110011 && mem_rdata_instr_reg[31:12] == 'b11001000001000000010) && ENABLE_COUNTERS && ENABLE_COUNTERS64;

			instr_ecall_ebreak[ID] <= ((mem_rdata_instr_reg[6:0] == 7'b1110011 && !mem_rdata_instr_reg[31:21] && !mem_rdata_instr_reg[19:7]) );

			
			is_slli_srli_srai[ID] <= is_alu_reg_imm[IF] && |{
				mem_rdata_instr_reg[14:12] == 3'b001 && mem_rdata_instr_reg[31:25] == 7'b0000000,
				mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0000000,
				mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0100000
			};

			is_jalr_addi_slti_sltiu_xori_ori_andi[ID] <= instr_jalr[IF] || is_alu_reg_imm[IF] && |{
				mem_rdata_instr_reg[14:12] == 3'b000,
				mem_rdata_instr_reg[14:12] == 3'b010,
				mem_rdata_instr_reg[14:12] == 3'b011,
				mem_rdata_instr_reg[14:12] == 3'b100,
				mem_rdata_instr_reg[14:12] == 3'b110,
				mem_rdata_instr_reg[14:12] == 3'b111
			};

			is_sll_srl_sra[ID] <= is_alu_reg_reg[IF] && |{
				mem_rdata_instr_reg[14:12] == 3'b001 && mem_rdata_instr_reg[31:25] == 7'b0000000,
				mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0000000,
				mem_rdata_instr_reg[14:12] == 3'b101 && mem_rdata_instr_reg[31:25] == 7'b0100000
			};

			
			(* parallel_case *)
			case (1'b1)
				instr_jal[IF]:
					decoded_imm[ID] <= decoded_imm_j;
				|{instr_lui[IF], instr_auipc[IF]}:
					decoded_imm[ID] <= {mem_rdata_instr_reg[31:12],12'b0};
				|{instr_jalr[IF], is_lb_lh_lw_lbu_lhu[IF], is_alu_reg_imm[IF]}:
					decoded_imm[ID] <= $signed(mem_rdata_instr_reg[31:20]);
				is_beq_bne_blt_bge_bltu_bgeu[IF]:
					decoded_imm[ID] <= $signed({mem_rdata_instr_reg[31], mem_rdata_instr_reg[7], mem_rdata_instr_reg[30:25], mem_rdata_instr_reg[11:8], 1'b0});
				is_sb_sh_sw[IF]:
					decoded_imm[ID] <= $signed({mem_rdata_instr_reg[31:25], mem_rdata_instr_reg[11:7]});
				default:
					decoded_imm[ID] <= 'bx;
			endcase
		end

		/** maintaining instruction type for next stages */
		instr_lui[ID] 	<= instr_lui[IF];
		instr_auipc[ID] <= instr_auipc[IF];
		instr_jal[ID]	<= instr_jal[IF];
		instr_jal[RR]	<= instr_jal[ID];
		instr_jalr[ID]	<= instr_jalr[IF];
		instr_jalr[RR]	<= instr_jalr[ID];
		decoded_rs1[ID] <= decoded_rs1[IF];
		decoded_rs2[ID] <= decoded_rs2[IF];
		/**	clear load tag if meeting branch/jal/jarl instruction*/
		is_lb_lh_lw_lbu_lhu[ID] <= is_lb_lh_lw_lbu_lhu[IF] && clk_temp[2];
		is_lb_lh_lw_lbu_lhu[RR] <= is_lb_lh_lw_lbu_lhu[ID] && clk_temp[3];
		is_lb_lh_lw_lbu_lhu[EX] <= is_lb_lh_lw_lbu_lhu[RR] && clk_temp[4];
		is_lb_lh_lw_lbu_lhu[BUB_4] <= is_lb_lh_lw_lbu_lhu[EX] && clk_temp[5];
		is_lb_lh_lw_lbu_lhu[BUB_5] <= is_lb_lh_lw_lbu_lhu[BUB_4] && clk_temp[6];
		is_sb_sh_sw[ID] <= is_sb_sh_sw[IF];
		is_sb_sh_sw[RR] <= is_sb_sh_sw[ID];
		instr_beq[RR] 	<= instr_beq[ID];
		instr_bne[RR] 	<= instr_bne[ID];
		instr_bge[RR] 	<= instr_bge[ID];
		instr_bgeu[RR]	<= instr_bgeu[ID];
		instr_xori[RR]	<= instr_xori[ID];
		instr_xor[RR]	<= instr_xor[ID];
		instr_ori[RR]	<= instr_ori[ID];
		instr_or[RR]	<= instr_or[ID];
		instr_andi[RR]	<= instr_andi[ID];
		instr_and[RR]	<= instr_and[ID];
		instr_sll[RR]	<= instr_sll[ID];
		instr_slli[RR]	<= instr_slli[ID];
		instr_srl[RR]	<= instr_srl[ID];
		instr_srli[RR]	<= instr_srli[ID];
		instr_sra[RR]	<= instr_sra[ID];
		instr_srai[RR]	<= instr_srai[ID];
		instr_sub[RR]	<= instr_sub[ID];
		
		instr_lb[RR]	<= instr_lb[ID];
		instr_lbu[RR]	<= instr_lbu[ID];
		instr_lh[RR]	<= instr_lh[ID];
		instr_lhu[RR]	<= instr_lhu[ID];
		instr_lw[RR]	<= instr_lw[ID];

		is_beq_bne_blt_bge_bltu_bgeu[ID] <= is_beq_bne_blt_bge_bltu_bgeu[IF];
		is_beq_bne_blt_bge_bltu_bgeu[RR] <= is_beq_bne_blt_bge_bltu_bgeu[ID];
				
		/** inilization */
		if (!resetn) begin
			is_beq_bne_blt_bge_bltu_bgeu[IF] <= 0;

			for(i=0; i<5; i=i+1) begin 
				instr_beq[i]   <= 0;
				instr_bne[i]   <= 0;
				instr_blt[i]   <= 0;
				instr_bge[i]   <= 0;
				instr_bltu[i]  <= 0;
				instr_bgeu[i]  <= 0;

				instr_addi[i]  <= 0;
				instr_slti[i]  <= 0;
				instr_sltiu[i] <= 0;
				instr_xori[i]  <= 0;
				instr_ori[i]   <= 0;
				instr_andi[i]  <= 0;

				instr_add[i]   <= 0;
				instr_sub[i]   <= 0;
				instr_sll[i]   <= 0;
				instr_slt[i]   <= 0;
				instr_sltu[i]  <= 0;
				instr_xor[i]   <= 0;
				instr_srl[i]   <= 0;
				instr_sra[i]   <= 0;
				instr_or[i]    <= 0;
				instr_and[i]   <= 0;
			end
		end
	end


	

	reg set_mem_do_rinst;
	reg set_mem_do_rdata;
	reg set_mem_do_wdata;

	//reg latched_store;
	reg latched_stalu;
	reg latched_branch;
	reg latched_compr;
	reg latched_trace;
	reg latched_is_lu[12:0];
	reg latched_is_lh[12:0];
	reg latched_is_lb[12:0];
	(* dont_touch = "true" *)reg [regindex_bits-1:0] latched_rd[11:0];
	(* dont_touch = "true" *)reg load_reg_lr;
	reg branch_instr[11:0];

	
	(* mark_debug = "true" *)reg [31:0] alu_out, alu_out_q;
	reg alu_out_0, alu_out_0_q;
	reg alu_wait, alu_wait_2;

	reg [31:0] alu_add_sub;
	reg [31:0] alu_shl, alu_shr;
	reg alu_eq, alu_ltu, alu_lts;

	/** operation */
	generate if (TWO_CYCLE_ALU) begin
		always @(posedge clk) begin
			alu_add_sub <= instr_sub[RR] ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
			alu_eq <= reg_op1 == reg_op2;
			alu_lts <= $signed(reg_op1) < $signed(reg_op2);
			alu_ltu <= reg_op1 < reg_op2;
			alu_shl <= reg_op1 << reg_op2[4:0];
			alu_shr <= $signed({instr_sra[RR] || instr_srai[RR] ? reg_op1[31] : 1'b0, reg_op1}) >>> reg_op2[4:0];
		end
	end else begin
		always @* begin
			alu_add_sub = instr_sub[RR] ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
			alu_eq = reg_op1 == reg_op2;
			alu_lts = $signed(reg_op1) < $signed(reg_op2);
			alu_ltu = reg_op1 < reg_op2;
			alu_shl = reg_op1 << reg_op2[4:0];
			alu_shr = $signed({instr_sra[RR] || instr_srai[RR] ? reg_op1[31] : 1'b0, reg_op1}) >>> reg_op2[4:0];
		end
	end endgenerate

	always @* begin
		alu_out_0 = 'bx;
		(* parallel_case, full_case *)
		case (1'b1)
			instr_beq[RR]:
				alu_out_0 = alu_eq;
			instr_bne[RR]:
				alu_out_0 = !alu_eq;
			instr_bge[RR]:
				alu_out_0 = !alu_lts;
			instr_bgeu[RR]:
				alu_out_0 = !alu_ltu;
			is_slti_blt_slt[RR] && (!TWO_CYCLE_COMPARE || !{instr_beq[RR],instr_bne[RR],instr_bge[RR],instr_bgeu[RR]}):
				alu_out_0 = alu_lts;
			is_sltiu_bltu_sltu[RR] && (!TWO_CYCLE_COMPARE || !{instr_beq[RR],instr_bne[RR],instr_bge[RR],instr_bgeu[RR]}):
				alu_out_0 = alu_ltu;
		endcase

		alu_out = 'bx;
		(* parallel_case, full_case *)
		case (1'b1)
			is_lui_auipc_jal_jalr_addi_add_sub[RR] || is_lb_lh_lw_lbu_lhu[RR] || is_sb_sh_sw[RR]:
				alu_out = alu_add_sub;
			is_compare[RR]:
				alu_out = alu_out_0;
			instr_xori[RR] || instr_xor[RR]:
				alu_out = reg_op1 ^ reg_op2;
			instr_ori[RR] || instr_or[RR]:
				alu_out = reg_op1 | reg_op2;
			instr_andi[RR] || instr_and[RR]:
				alu_out = reg_op1 & reg_op2;
			BARREL_SHIFTER && (instr_sll[RR] || instr_slli[RR]):
				alu_out = alu_shl;
			BARREL_SHIFTER && (instr_srl[RR] || instr_srli[RR] || instr_sra[RR] || instr_srai[RR]):
				alu_out = alu_shr;
		endcase


	end

	



	always @(posedge clk or negedge resetn) begin
		if(!resetn) begin
			/** initial registers */
			if (REGS_INIT_ZERO) begin
				for (i = 0; i < regfile_size; i = i+1)
					cpuregs[i] = 0;
			end
			// cpuregs[0] <= 0;
			for (i = 0; i < regfile_size; i = i+1) begin
				cpuregs_lock[i] <= 4'd0;
			end
		end
		else begin 	
			for (i = 1; i < regfile_size; i = i+1) begin

				if (cpuregs_write_ex && latched_rd[EX] == i) begin
					cpuregs[i] = reg_out[EX];
					cpuregs_lock[i] <= 4'd2; //???
				end
				else if (cpuregs_write_rr && latched_rd[RR] == i && !cpuregs_write_ex) begin
					cpuregs[i] = reg_out[RR];
					cpuregs_lock[i] <= 4'd3; //???
				end
				else if (load_reg_lr && latched_rd[LR] == i) begin
					cpuregs[i] = reg_out[LR];
					if(cpuregs_lock[i] == 0)
						cpuregs_lock[i] <= cpuregs_lock[i];
					else
						cpuregs_lock[i] <= cpuregs_lock[i] - 4'd1;
				end
				else begin
					if(cpuregs_lock[i] == 0)
						cpuregs_lock[i] <= cpuregs_lock[i];
					else
						cpuregs_lock[i] <= cpuregs_lock[i] - 4'd1;
				end
			end
			// for (i = 0; i < regfile_size; i = i+1) begin
			// 	if(cpuregs_lock[i] == 0)
			// 		cpuregs_lock[i] <= cpuregs_lock[i];
			// 	else
			// 		cpuregs_lock[i] <= cpuregs_lock[i] - 4'd1;
			// end
// 			if (resetn && load_reg_lr && latched_rd[LR]) begin				
// 				if(cpuregs_lock[latched_rd[LR]] == 0) begin
// 					cpuregs[latched_rd[LR]] = reg_out[LR];
// 				end
// `ifdef PRINT_TEST_1
// 				if(count_test < NUM_PRINT)
// 					$display("latched_rd: %d, value: %08x", latched_rd[LR], reg_out[LR]);
// `endif
// 			end
// 			if (resetn && cpuregs_write_rr && latched_rd[RR] && !cpuregs_write_ex) begin
// 				if(cpuregs_lock[latched_rd[RR]] == 0) begin
// 					cpuregs[latched_rd[RR]] = reg_out[RR];
// 					cpuregs_lock[latched_rd[RR]] <= 4'd3; //???
// `ifdef PRINT_TEST_1
// 					if(count_test < NUM_PRINT)
// 						$display("ID, latched_rd: %d, value: %08x", latched_rd[ID], reg_out[ID]);
// `endif
// 				end
// 			end
// 			if (resetn && cpuregs_write_ex && latched_rd[EX]) begin
// 				if(cpuregs_lock[latched_rd[EX]] == 0) begin
// 					cpuregs[latched_rd[EX]] = reg_out[EX];
// 					cpuregs_lock[latched_rd[EX]] <= 4'd2; //???
// `ifdef PRINT_TEST_1
// 					if(count_test < NUM_PRINT)
// 						$display("EX, latched_rd: %d, value: %08x", latched_rd[EX], reg_out[EX]);
// `endif
// 				end
// 			end
		end
	end

	// compare decoded_rs[IF] with latched_rd[BUB_5, BUB_4, EX, RR, ID], and get bitmap;
	//	the ID is highest priority, i.e.,bitmap[4];
	reg [4:0]	bitmap_rs1, bitmap_rs2;	
	always @(posedge clk) begin
		if(decoded_rs1[IF] == latched_rd[ID])			bitmap_rs1 <= 5'h10;
		else if(decoded_rs1[IF] == latched_rd[RR])		bitmap_rs1 <= 5'h8;
		else if(decoded_rs1[IF] == latched_rd[EX])		bitmap_rs1 <= 5'h4;
		else if(decoded_rs1[IF] == latched_rd[BUB_4])	bitmap_rs1 <= 5'h2;
		else if(decoded_rs1[IF] == latched_rd[BUB_5])	bitmap_rs1 <= 5'h1;
		else											bitmap_rs1 <= 5'h0;

		if(decoded_rs2[IF] == latched_rd[ID])			bitmap_rs2 <= 5'h10;
		else if(decoded_rs2[IF] == latched_rd[RR])		bitmap_rs2 <= 5'h8;
		else if(decoded_rs2[IF] == latched_rd[EX])		bitmap_rs2 <= 5'h4;
		else if(decoded_rs2[IF] == latched_rd[BUB_4])	bitmap_rs2 <= 5'h2;
		else if(decoded_rs2[IF] == latched_rd[BUB_5])	bitmap_rs2 <= 5'h1;
		else											bitmap_rs2 <= 5'h0;
	end

	(* mark_debug = "true" *)reg 	usingLastValue_rs1_tag, usingLastValue_rs2_tag;
	// data-harzard;
	always @* begin
		usingLastValue_rs1_tag = 1'b0;
		if(decoded_rs1[ID]) begin
			(* parallel_case *)
			case(1)
				// bitmap_rs1[4]&cpuregs_write[RR]: 	cpuregs_rs1 = reg_out_r[RR];
				bitmap_rs1[4]&cpuregs_write[RR]: begin
					usingLastValue_rs1_tag = 1'b1;
					cpuregs_rs1 = 32'b0;
				end
				bitmap_rs1[3]&cpuregs_write[EX]: 	cpuregs_rs1 = reg_out_r[EX];
				bitmap_rs1[2]&cpuregs_write[BUB_4]: cpuregs_rs1 = reg_out_r[BUB_4];
				bitmap_rs1[1]&cpuregs_write[BUB_5]: cpuregs_rs1 = reg_out_r[BUB_5];
				bitmap_rs1[0]&load_reg_lr: 			cpuregs_rs1 = reg_out[LR];
				default: 							cpuregs_rs1 = cpuregs[decoded_rs1[ID]];
			endcase
		end
		else begin
			cpuregs_rs1 = 0;
		end
	end

	always @* begin	
		usingLastValue_rs2_tag = 1'b0;
		if(decoded_rs2[ID]) begin
			(* parallel_case *)
			case(1)
				// bitmap_rs2[4]&cpuregs_write[RR]: 	cpuregs_rs2 = reg_out_r[RR];
				bitmap_rs2[4]&cpuregs_write[RR]: begin
					usingLastValue_rs2_tag = 1'b1;
					cpuregs_rs2 = 32'b0;
				end 
				bitmap_rs2[3]&cpuregs_write[EX]: 	cpuregs_rs2 = reg_out_r[EX];
				bitmap_rs2[2]&cpuregs_write[BUB_4]: cpuregs_rs2 = reg_out_r[BUB_4];
				bitmap_rs2[1]&cpuregs_write[BUB_5]: cpuregs_rs2 = reg_out_r[BUB_5];
				bitmap_rs2[0]&load_reg_lr: 			cpuregs_rs2 = reg_out[LR];
				default: 							cpuregs_rs2 = cpuregs[decoded_rs2[ID]];
			endcase
		end
		else begin
			cpuregs_rs2 = 0;
		end
	end

	// always @* begin
	// 	decoded_rs = 'bx;
	// 	if (ENABLE_REGS_DUALPORT) begin
	// 		if(decoded_rs1[ID]) begin
	// 			cpuregs_rs1 = cpuregs[decoded_rs1[ID]];
	// 			if(decoded_rs1[ID] == latched_rd[LR] 	&& load_reg_lr) 		 cpuregs_rs1 = reg_out[LR];
	// 			if(decoded_rs1[ID] == latched_rd[BUB_5] && cpuregs_write[BUB_5]) cpuregs_rs1 = reg_out_r[BUB_5];
	// 			if(decoded_rs1[ID] == latched_rd[BUB_4] && cpuregs_write[BUB_4]) cpuregs_rs1 = reg_out_r[BUB_4];
	// 			if(decoded_rs1[ID] == latched_rd[EX] 	&& cpuregs_write[EX])	 cpuregs_rs1 = reg_out_r[EX];
	// 			if(decoded_rs1[ID] == latched_rd[RR] 	&& cpuregs_write[RR])	 cpuregs_rs1 = reg_out_r[RR];
	// 		end
	// 		else begin
	// 			cpuregs_rs1 = 0;
	// 		end
	// 		if(decoded_rs2[ID]) begin
	// 			cpuregs_rs2 = cpuregs[decoded_rs2[ID]];
	// 			if(decoded_rs2[ID] == latched_rd[LR] 	&& load_reg_lr) 		 cpuregs_rs2 = reg_out[LR];
	// 			if(decoded_rs2[ID] == latched_rd[BUB_5] && cpuregs_write[BUB_5]) cpuregs_rs2 = reg_out_r[BUB_5];
	// 			if(decoded_rs2[ID] == latched_rd[BUB_4] && cpuregs_write[BUB_4]) cpuregs_rs2 = reg_out_r[BUB_4];
	// 			if(decoded_rs2[ID] == latched_rd[EX] 	&& cpuregs_write[EX])	 cpuregs_rs2 = reg_out_r[EX];
	// 			if(decoded_rs2[ID] == latched_rd[RR] 	&& cpuregs_write[RR])	 cpuregs_rs2 = reg_out_r[RR];
	// 		end
	// 		else begin
	// 			cpuregs_rs2 = 0;
	// 		end
	// 	end 
	// end

	reg load_realted_rs1_tag, load_realted_rs2_tag;

	always @* begin
		//load_realted_tag = 1'b0;
		if( (decoded_rs1[ID] == latched_rd[RR]  	&& is_lb_lh_lw_lbu_lhu[RR]) || 
			(decoded_rs1[ID] == latched_rd[EX]  	&& is_lb_lh_lw_lbu_lhu[EX]) || 
			(decoded_rs1[ID] == latched_rd[BUB_4]  	&& is_lb_lh_lw_lbu_lhu[BUB_4]) ||
			(decoded_rs1[ID] == latched_rd[BUB_5]  	&& is_lb_lh_lw_lbu_lhu[BUB_5])) begin
				load_realted_rs1_tag = 1'b1;
		end
		else begin
			load_realted_rs1_tag = 1'b0;
		end
		if	((decoded_rs2[ID] == latched_rd[RR]  	&& is_lb_lh_lw_lbu_lhu[RR]) || 
			(decoded_rs2[ID] == latched_rd[EX]  	&& is_lb_lh_lw_lbu_lhu[EX]) || 
			(decoded_rs2[ID] == latched_rd[BUB_4]  	&& is_lb_lh_lw_lbu_lhu[BUB_4]) ||
			(decoded_rs2[ID] == latched_rd[BUB_5]  	&& is_lb_lh_lw_lbu_lhu[BUB_5])) begin
				load_realted_rs2_tag = 1'b1;
		end
		else begin
			load_realted_rs2_tag = 1'b0;
		end
	end
	
	
	/** calculate clk
	*	IF:			mem_rinst<= 1;
	*	mem_rinst:  wait read instr_sram (1st clk), current_pc[IF];
	*	clk[0]:		wait read instr_sram (2nd clk), current_pc[BUB_1];
	*	clk[1]:		read instr_sram, current_pc[BUB_2];
	*	clk[2]:		ID, current_pc[BUB_3];
	*	clk[3]:		RR, current_pc[ID];
	*	clk[4]:		EX, RWM, mem_rctx<= 1;
	*	clk[5]:		wait read data_sram (1st clk), [EX];
	*	clk[6]:		wait read data_sram (2nd clk), [BUB_4];
	*	clk[7]:		read instr_sram, i.e, LR, [BUB_5];
	*	clk[8]:		
	*	clk[9]:	
	*	clk[10]:
	*/

`ifdef PRINT_TEST
	reg [9:0] count_test;
	always @(posedge clk) begin
		/**read instr*/
		if(!resetn) begin
			count_test <= 10'd0;
		end
		else if((cpuregs_write_ex || cpuregs_write_rr || load_reg_lr)&&(count_test < NUM_PRINT)) begin
			count_test <= count_test + 10'd1;
			$display("count_test is %d", count_test);
			$display("****************registers*******************");
			for(i = 0; i<32; i=i+1)
				$display("reg[%d]: %08x",i, cpuregs[i]);
			$display("****************registers*******************");
		end
		// if(clk_temp[0] == 1'b1 && count_test < NUM_PRINT) begin
		// 	$display("stage clk_temp[0]: current_pc[BUB_1] is %08x", current_pc[BUB_1]);
		// end
		// /**get instr from ram*/
		if(count_test < NUM_PRINT)
			$display("mem_rinst is %d", mem_rinst);
		if(clk_temp[1] && count_test < NUM_PRINT) begin
			$display("stage clk_temp[1]: current_pc[BUB_2] is %08x, instr is %08x", current_pc[BUB_2], mem_rdata_instr);
		end
		// if(next_stage[RR]&RM_B && clk_temp[4] && !branch_hit_ex && !instr_trap && count_test < NUM_PRINT)
		// 	$display("reg_op1_2b[EX] is %d", alu_out[1:0]);
		// if(next_stage[BUB_5] == LR_B && clk_temp[7] && count_test < NUM_PRINT)
		// 	$display("mem_wordsize[BUB_5] is %d, reg_op1_2b[BUB_5] is %d, mem_rdata is %08x, mem_rdata_word is %08x", mem_wordsize[BUB_5], reg_op1_2b[BUB_5], mem_rdata, mem_rdata_word);
		// if(count_test < NUM_PRINT) begin
		// 	$display("is_lb_lh_lw_lbu_lhu[RR] is %d, latched_rd[RR] is %d", is_lb_lh_lw_lbu_lhu[RR], latched_rd[RR]);
		// 	$display("is_lb_lh_lw_lbu_lhu[EX] is %d, latched_rd[EX] is %d", is_lb_lh_lw_lbu_lhu[EX], latched_rd[EX]);
		// 	$display("is_lb_lh_lw_lbu_lhu[BUB_4] is %d, latched_rd[BUB_4] is %d", is_lb_lh_lw_lbu_lhu[BUB_4], latched_rd[BUB_4]);
		// 	$display("is_lb_lh_lw_lbu_lhu[BUB_5] is %d, latched_rd[BUB_5] is %d", is_lb_lh_lw_lbu_lhu[BUB_5], latched_rd[BUB_5]);
		// end
		// if(count_test < NUM_PRINT) begin
		// 	$display("latched_rd[RR] is %d, reg_out_r[RR] is %08x, cpuregs_write[RR] is %d, is_sb_sh_sw[RR] is %d", latched_rd[RR], reg_out_r[RR], cpuregs_write[RR], is_sb_sh_sw[RR]);
		// 	$display("latched_rd[EX] is %d, reg_out_r[EX] is %08x, cpuregs_write[EX] is %d", latched_rd[EX], reg_out_r[EX], cpuregs_write[EX]);
		// 	$display("latched_rd[BUB_4] is %d, reg_out_r[BUB_4] is %08x, cpuregs_write[BUB_4] is %d", latched_rd[BUB_4], reg_out_r[BUB_4], cpuregs_write[BUB_4]);
		// 	$display("latched_rd[BUB_5] is %d, reg_out_r[BUB_5] is %08x, cpuregs_write[RR] is %d", latched_rd[BUB_5], reg_out_r[BUB_5], cpuregs_write[BUB_5]);
		// 	$display("latched_rd[LR] is %d, reg_out[LR] is %08x, load_reg_lr is %d", latched_rd[LR], reg_out[LR], load_reg_lr);
		// end
		// if(count_test < NUM_PRINT) begin
		// 	$display("next_stage[ID] is %d, next_stage[RR] is %d, next_stage[EX] is %d", next_stage[ID], next_stage[RR], next_stage[EX]);
		// end
		// if(cpuregs_write[BUB_4] && count_test < NUM_PRINT) begin
		// 	$display("latched_rd[BUB_4] is %d, reg_out_r[BUB_5] is %08x, cpuregs_rs1 is %08x", latched_rd[BUB_4], reg_out[BUB_4], cpuregs_rs1);
		// end
		// if(mem_wren && count_test < NUM_PRINT) begin
		// 	$display("mem_wren, mem_addr is %08x, mem_wstrb is %x, mem_wdata is %08x",mem_addr, mem_wstrb, mem_wdata);
		// end
		// if(mem_rden && count_test < NUM_PRINT) begin
		// 	$display("mem_addr is %08x",mem_addr);
		// end
		// if(clk_temp[3] && count_test < NUM_PRINT) begin
		// 	$display("instr_lbu[ID] is %d, instr_lhu[ID] is %d, instr_lw[ID] is %d", instr_lbu[ID], instr_lhu[ID], instr_lw[ID]);
		// end
		/** at RR stage */
		if(clk_temp[3] &&(count_test < NUM_PRINT)) begin
			if (instr_lui[ID])      $display("instr_lui");
			if (instr_auipc[ID])    $display("instr_auipc");
			if (instr_jal[ID])      $display("instr_jal");
			if (instr_jalr[ID])     $display("instr_jalr");

			if (instr_beq[ID])      $display("instr_beq");
			if (instr_bne[ID])      $display("instr_bne");
			if (instr_blt[ID])      $display("instr_blt");
			if (instr_bge[ID])      $display("instr_bge");
			if (instr_bltu[ID])     $display("instr_bltu");
			if (instr_bgeu[ID])     $display("instr_bgeu");

			if (instr_lb[ID])       $display("instr_lb");
			if (instr_lh[ID])       $display("instr_lh");
			if (instr_lw[ID])       $display("instr_lw");
			if (instr_lbu[ID])      $display("instr_lbu");
			if (instr_lhu[ID])      $display("instr_lhu");
			if (instr_sb[ID])       $display("instr_sb");
			if (instr_sh[ID])       $display("instr_sh");
			if (instr_sw[ID])       $display("instr_sw");

			if (instr_addi[ID])     $display("instr_addi");
			if (instr_slti[ID])     $display("instr_slti");
			if (instr_sltiu[ID])    $display("instr_sltiu");
			if (instr_xori[ID])     $display("instr_xori");
			if (instr_ori[ID])      $display("instr_ori");
			if (instr_andi[ID])     $display("instr_andi");
			if (instr_slli[ID])     $display("instr_slli");
			if (instr_srli[ID])     $display("instr_srli");
			if (instr_srai[ID])     $display("instr_srai");

			if (instr_add[ID])      $display("instr_add");
			if (instr_sub[ID])      $display("instr_sub");
			if (instr_sll[ID])      $display("instr_sll");
			if (instr_slt[ID])      $display("instr_slt");
			if (instr_sltu[ID])     $display("instr_sltu");
			if (instr_xor[ID])      $display("instr_xor");
			if (instr_srl[ID])      $display("instr_srl");
			if (instr_sra[ID])      $display("instr_sra");
			if (instr_or[ID])       $display("instr_or");
			if (instr_and[ID])      $display("instr_and");

			if (instr_ecall_ebreak[ID])  $display("instr_ecall_ebreak");

			$display("current_pc is %08x", current_pc[ID]);
			$display("decoded_imm is %08x", decoded_imm[ID]);
			$display("stage RR: decoded_rs1[ID] is %d, cpuregs[decoded_rs1[ID]] is %x", decoded_rs1[ID], cpuregs_rs1);
			$display("stage RR: decoded_rs2[ID] is %d, cpuregs[decoded_rs2[ID]] is %x", decoded_rs2[ID], cpuregs_rs2);
			$display("stage RR: decoded_rd[ID] is %d", latched_rd[ID]);
		end
		/** EX stage */
			// if(clk_temp[4]&& (count_test < NUM_PRINT)) begin
			// 	// $display("is_lbu_lhu_lw[RR] is %d",is_lbu_lhu_lw[RR]);
			// 	$display("stage EX: reg_op1 is %08x, reg_op2 is %08x", reg_op1, reg_op2);
			// 	$display("alu_add_sub is %08x, alu_out_0 is %d", alu_add_sub, alu_out_0);
			// end
			// if(clk_temp[7]&& (count_test < NUM_PRINT)) begin
			// 	$display("mem_rdata is %08x",mem_rdata);
			// end
			// if(clk_temp[7]&& count_test < NUM_PRINT)
			// 	$display("reg_out[BUB_5] is %08x, latched_is_lu[BUB_5] is %d, latched_is_lb[BUB_5] is %d, latched_is_lh[BUB_5] is %d",reg_out[BUB_5], latched_is_lu[BUB_5], latched_is_lb[BUB_5], latched_is_lh[BUB_5]);
		// if(count_test < 10'd10) begin
		// 	for(i=0; i<5; i=i+1)
		// 		$display("clk_temp[%d]: %d",i, clk_temp[i]);
		// end
		// if(clk_temp[8]) begin
		// 	$display("stage LR: load_reg_lr is %d, reg_out[LR] is %08x", load_reg_lr, reg_out[LR]);
		// 	$display("mem_rdata: %08x, mem_rdata_word: %08x", mem_rdata, mem_rdata_word);
		// 	//$display("latched_is_lb[BUB_5] is %d", latched_is_lb[BUB_5]);
		// 	$display("mem_wordsize[BUB_5] is %d, reg_op1_2b[BUB_5] is %d",mem_wordsize[BUB_5], reg_op1_2b[BUB_5]);
		// end
		// if(branch_hit_id) begin
		// 	$display("Jal, addr is %08x", branch_pc_id);
		// end
		// if(pre_instr_finished_lr) begin
		// 	$display("finish one instr");
		// end
		// if(branch_hit_ex) begin
		// 	$display("hit branch, branch_pc_ex is %08x", branch_pc_ex);
		// end
		// if(branch_hit_id) begin
		// 	$display("hit branch, branch_pc_id is %08x", branch_pc_id);
		// end
		if((mem_rden||mem_wren)&& count_test < NUM_PRINT) begin
			$display("mem_rden: %d, mem_addr: %08x", mem_rden, mem_addr);
			$display("mem_wren: %d, mem_addr: %08x, mem_wdata: %08x, mem_wstrb: %x",mem_wren, mem_addr, mem_wdata, mem_wstrb);
		end
		// if(instr_ecall_ebreak[ID]) begin
		// 	$display("instr_ecall_ebreak[ID] is %d", instr_ecall_ebreak[ID]);
		// 	$finish;
		// end
		if(instr_trap && count_test < NUM_PRINT) begin
			$display("trap instr");
			// $finish;
		end
	end
`endif

				
	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			for(i=0; i<11; i=i+1)
				clk_temp[i] <= 1'b0;
		end
		else begin
			clk_temp[0] <= mem_rinst;
			for(i=1; i<11; i=i+1)
				clk_temp[i] <= clk_temp[i-1];
			if(branch_hit_rr) begin
				clk_temp[0] <= 1'b0;
				clk_temp[1] <= 1'b0;
				clk_temp[2] <= 1'b0;
				clk_temp[3] <= 1'b0;
			end
			if(load_realted_rr) begin
				clk_temp[0] <= 1'b0;
				clk_temp[1] <= 1'b0;
				clk_temp[2] <= 1'b0;
				clk_temp[3] <= 1'b0;
			end
			if(branch_hit_ex) begin
				clk_temp[0] <= 1'b0;
				clk_temp[1] <= 1'b0;
				clk_temp[2] <= 1'b0;
				clk_temp[3] <= 1'b0;
				clk_temp[4] <= 1'b0;
			end
			current_pc[BUB_1] 	<= mem_rinst_addr;
			current_pc[BUB_2] 	<= current_pc[BUB_1];
			current_pc[BUB_3] 	<= current_pc[BUB_2];
			current_pc[ID] 		<= current_pc[BUB_3];
			current_pc[RR] 		<= current_pc[ID];
			decoded_imm[RR] 	<= decoded_imm[ID];
			decoded_imm[EX] 	<= decoded_imm[RR];
			decoded_imm[RWM] 	<= decoded_imm[EX];
			latched_rd[ID] 		<= decoded_rd[IF];
			latched_rd[RR] 		<= latched_rd[ID];
			latched_rd[EX] 		<= latched_rd[RR];
			latched_rd[BUB_4]	<= latched_rd[EX];
			latched_rd[BUB_5]	<= latched_rd[BUB_4];
			//latched_rd[BUB_6]	<= decoded_rd[BUB_5];
			latched_rd[LR] 		<= latched_rd[BUB_5];
			// reg_out[BUB_4] 		<= reg_out[EX];
			// reg_out[BUB_5] 		<= reg_out[BUB_4];
			reg_out_r[EX] 		<= reg_out_r[RR];
			reg_out_r[BUB_4] 	<= reg_out_r[EX];
			reg_out_r[BUB_5] 	<= reg_out_r[BUB_4];
			cpuregs_write[EX]	<= cpuregs_write[RR];
			cpuregs_write[BUB_4]<= cpuregs_write[EX];
			cpuregs_write[BUB_5]<= cpuregs_write[BUB_4];
			cpuregs_write[LR]	<= cpuregs_write[BUB_5];
			//reg_out[BUB_6] 		<= reg_out[BUB_5];

			reg_op1_2b[EX] 		<= alu_out[1:0];
			reg_op1_2b[BUB_4] 	<= reg_op1_2b[EX];
			reg_op1_2b[BUB_5] 	<= reg_op1_2b[BUB_4];
			//reg_op1_2b[BUB_6] <= reg_op1_2b[BUB_5];
			mem_wordsize[BUB_4] <= mem_wordsize[RWM];
			mem_wordsize[BUB_5] <= mem_wordsize[BUB_4];
			//mem_wordsize[BUB_6] 	<= mem_wordsize[BUB_5];
			// latched_is_lu[BUB_4] 	<= latched_is_lu[EX];
			// latched_is_lu[BUB_5] 	<= latched_is_lu[BUB_4];
			//latched_is_lu[BUB_6] 	<= latched_is_lu[BUB_5];
			instr_finished[BUB_4] 	<= instr_finished[EX];
			instr_finished[BUB_5] 	<= instr_finished[BUB_4];
			//instr_finished[BUB_6] 	<= instr_finished[BUB_5];

			branch_instr[BUB_4] <= branch_instr[EX];
			branch_instr[BUB_5] <= branch_instr[BUB_4];

			{latched_is_lu[BUB_4],latched_is_lh[BUB_4],latched_is_lb[BUB_4]} <= {latched_is_lu[EX],
				latched_is_lh[EX],latched_is_lb[EX]};
			{latched_is_lu[BUB_5],latched_is_lh[BUB_5],latched_is_lb[BUB_5]} <= {latched_is_lu[BUB_4],latched_is_lh[BUB_4],latched_is_lb[BUB_4]};
			{instr_sb[RR],instr_sh[RR],instr_sw[RR]} <= {instr_sb[ID],instr_sh[ID],instr_sw[ID]};
		end
	end 

	/**instr_ecall_ebreak*/
	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			finish <= 1'b0;
		end
		else begin
			//if(instr_ecall_ebreak[ID]||instr_trap)
			if(instr_ecall_ebreak[ID]) begin
				finish <= 1'b1;
				// $display("finish");
				// $finish;
			end
			else 
				finish <= finish;
		end
	end

	/**IF: instruction fetch*/
	reg unstart_tag;
	always @(posedge clk or negedge resetn) begin
		if(!resetn) begin
			unstart_tag <= 1'b1;
			mem_rinst <= 1'b0;
			mem_rinst_addr <= 32'b0;
		end
		else begin 
			if(unstart_tag) begin
				mem_rinst <= 1'b1;
				mem_rinst_addr <= PROGADDR_RESET;
				unstart_tag <= 1'b0;
`ifdef PRINT_TEST
				$display("start program");
`endif
			end
			/** pipelined */
			else if(!finish) begin
				mem_rinst <= 1;
				mem_rinst_addr <= branch_hit_ex? branch_pc_ex : load_realted_rr? refetch_pc_rr: branch_hit_rr? branch_pc_rr :mem_rinst_addr+32'd4;
`ifdef PRINT_TEST
				if(count_test < NUM_PRINT) begin
					$display("=============");
					$display("at IF stage: branch_hit_rr:%d, branch_hit_ex:%d, load_realted_rr:%d, mem_rinst_addr:%08x", branch_hit_rr, branch_hit_ex, load_realted_rr, branch_hit_ex? branch_pc_ex : load_realted_rr? refetch_pc_rr: branch_hit_rr? branch_pc_rr :mem_rinst_addr+32'd4);
				end
`endif
			end
			else begin
				mem_rinst <= 1'b0;
			end
		end
	end
	always @* begin
		current_pc[IF] = mem_rinst_addr;
	end
	
	/**ID: instruction decode*/
	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			next_stage[ID] <= 0;
		end
		else begin
			//next_stage[ID] <= 0;
			if(clk_temp[2]) begin 
				next_stage[ID] <= RR_B;
			end
			else begin
				next_stage[ID] <= 0;
			end
		end
	end

	/** RR: read register */
	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			next_stage[RR] <= 0;
			load_realted_rr <= 1'b0;
		end
		else begin
			trace_data[3:0]	<= 4'd0;
			//next_stage[RR] <= 0;
			//cpuregs_write[RR] = 0;
			load_realted_rr <= 1'b0;
			branch_hit_rr <= 1'b0;
			cpuregs_write_rr <= 1'b0;
			branch_instr[RR] <= 1'b0;
			if(next_stage[ID] == RR_B && clk_temp[3] && !load_realted_rr && !branch_hit_rr && !branch_hit_ex) begin 
				reg_op1 <= 'bx;
				reg_op2 <= 'bx;

				(* parallel_case *)
				case (1'b1)					
					ENABLE_COUNTERS && is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_rdcycle[ID]:
								reg_out[RR] <= count_cycle[31:0];
							instr_rdcycleh[ID] && ENABLE_COUNTERS64:
								reg_out[RR] <= count_cycle[63:32];
							instr_rdinstr[ID]:
								reg_out[RR] <= count_instr[31:0];
							instr_rdinstrh[ID] && ENABLE_COUNTERS64:
								reg_out[RR] <= count_instr[63:32];
						endcase
						next_stage[RR] <= LR_B;
trace_data[3:0]	<= 4'd1;
					end
					is_lui_auipc_jal[ID]: begin
						reg_op1 <= instr_lui[ID] ? 0 : current_pc[ID];
						reg_op2 <= instr_jal[ID] ? 32'd4 : decoded_imm[ID];
						if(instr_jal[ID]) begin
							branch_pc_rr <= current_pc[ID] + decoded_imm[ID];
							branch_hit_rr <= 1'b1;
							cpuregs_write_rr <= 1'b1;
							branch_instr[RR] <= 1'b1;
							reg_out[RR] <= current_pc[ID] + 32'd4;
							next_stage[RR] <= 0;
trace_data[3:0]	<= 4'd2;
						end
						else begin
							branch_hit_rr <= 1'b0;
							cpuregs_write_rr <= 1'b0;
							branch_instr[RR] <= 1'b0;
							next_stage[RR] <= EX_B;
trace_data[3:0]	<= 4'd3;
						end
					end
					is_lb_lh_lw_lbu_lhu[ID]: begin
						// reg_op1 <= cpuregs_rs1;
						reg_op1 <= (usingLastValue_rs1_tag)? reg_out_r[RR]: cpuregs_rs1;
						reg_op2 <= decoded_imm[ID];
						next_stage[RR] <= RM_B;
trace_data[3:0]	<= 4'd4;
						if(load_realted_rs1_tag) begin
							refetch_pc_rr <= current_pc[ID];
							load_realted_rr <= 1'b1;
							next_stage[RR] <= 0;
trace_data[3:0]	<= 4'd5;
						end
					end
					// is_slli_srli_srai && !BARREL_SHIFTER: begin
					// 	reg_op1 <= cpuregs_rs1;
					// 	reg_sh <= decoded_rs2;
					// 	cpu_state <= cpu_state_shift;
					// end
					is_jalr_addi_slti_sltiu_xori_ori_andi[ID], is_slli_srli_srai[ID] && BARREL_SHIFTER: begin
						// reg_op1 <= cpuregs_rs1;
						reg_op1 <= (usingLastValue_rs1_tag)? reg_out_r[RR]: cpuregs_rs1;
						reg_op2 <= is_slli_srli_srai[ID]? decoded_rs2[ID] :decoded_imm[ID];
						next_stage[RR] <= EX_B;
trace_data[3:0]	<= 4'd6;
						if(load_realted_rs1_tag) begin
							refetch_pc_rr <= current_pc[ID];
							load_realted_rr <= 1'b1;
							next_stage[RR] <= 0;
trace_data[3:0]	<= 4'd7;
						end
					end
					default: begin
						// reg_op1 <= cpuregs_rs1;
						reg_op1 <= (usingLastValue_rs1_tag)? reg_out_r[RR]: cpuregs_rs1;
						// reg_sh <= cpuregs_rs2;
						reg_sh <= (usingLastValue_rs2_tag)? reg_out_r[RR]: cpuregs_rs2;
						// reg_op2 <= cpuregs_rs2;
						reg_op2 <= (usingLastValue_rs2_tag)? reg_out_r[RR]: cpuregs_rs2;
						(* parallel_case *)
						case (1'b1)
							is_sb_sh_sw[ID]: begin
								// reg_op1 <= cpuregs_rs1 + decoded_imm[ID];
								reg_op1 <= ((usingLastValue_rs1_tag)? reg_out_r[RR]: cpuregs_rs1) + decoded_imm[ID];
								next_stage[RR] <= WM_B;
trace_data[3:0]	<= 4'd8;
								if(load_realted_rs1_tag || load_realted_rs2_tag) begin
									refetch_pc_rr <= current_pc[ID];
									load_realted_rr <= 1'b1;
									next_stage[RR] <= 0;
trace_data[3:0]	<= 4'd9;
								end
							end
							default: begin
								next_stage[RR] <= EX_B;
trace_data[3:0]	<= 4'd10;
								if(load_realted_rs1_tag || load_realted_rs2_tag) begin
									refetch_pc_rr <= current_pc[ID];
									load_realted_rr <= 1'b1;
									next_stage[RR] <= 0;
trace_data[3:0]	<= 4'd11;
								end
							end
						endcase
					end
				endcase
			end
			else begin
				next_stage[RR] <= 0;
			end
		end
	end

	/**assign reg_out_r and cpuregs_write[RR] just after RR stage (posedge clk)*/
	always @* begin
		cpuregs_write[RR] = 1'b0;
		reg_out_r[RR] = 0;
		if(next_stage[RR]&EX_B && clk_temp[4] && !branch_hit_ex && !instr_trap) begin 
			reg_out_r[RR] = 0;
			cpuregs_write[RR] = 1'b0;
			if(!is_beq_bne_blt_bge_bltu_bgeu[RR] && !is_sb_sh_sw[RR]) begin
				cpuregs_write[RR] = 1'b1;
				reg_out_r[RR] = (instr_jalr[RR]|instr_jal[RR])? current_pc[RR] + 32'd4: alu_out;
			end 
		end
	end

	/** EX: execution */
	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			next_stage[EX] <= 0;
			mem_wren <= 1'b0;
			mem_rden <= 1'b0;
			mem_addr <= 32'b0;
			branch_hit_ex <= 1'b0;
			cpuregs_write_ex <= 1'b0;
			instr_finished[EX] <= 1'b0;
			{latched_is_lu[EX], latched_is_lh[EX],latched_is_lb[EX]} <= 3'd0;
		end
		else begin
			next_stage[EX] <= 0;
			mem_wren <= 1'b0;
			mem_rden <= 1'b0;
			reg_out[EX] <= reg_out[RR];
			branch_instr[EX] <= branch_instr[RR];
			branch_hit_ex <= 1'b0;
			cpuregs_write_ex <= 1'b0;
			instr_finished[EX] <= 1'b0;
			{latched_is_lu[EX], latched_is_lh[EX],latched_is_lb[EX]} <= 3'd0;
			/** EX: execution */
			if(next_stage[RR]&EX_B && clk_temp[4] && !branch_hit_ex && !instr_trap) begin 
				reg_out[EX] <= alu_out;
				branch_pc_ex <= current_pc[RR] + decoded_imm[RR];
				if (is_beq_bne_blt_bge_bltu_bgeu[RR]) begin
					branch_hit_ex <= alu_out_0;
					next_stage[EX] <= 0;
					instr_finished[EX] <= !alu_out_0;
					branch_instr[EX] <= alu_out_0;
				end 
				else begin
					branch_hit_ex <= instr_jalr[RR];
					cpuregs_write_ex <= instr_jalr[RR];
					branch_pc_ex <= alu_out;
					if(instr_jalr[RR]) begin
						reg_out[EX] <= current_pc[RR] + 32'd4;
						next_stage[EX] <= 0;
					end
					else begin
						next_stage[EX] <= LR_B;
					end
				end
			end
			/** RWM: Read/Write Memory */			
			else if(next_stage[RR]&RM_B && clk_temp[4] && !branch_hit_ex && !instr_trap) begin
				// read mem;
				mem_addr <= alu_out;
				(* parallel_case, full_case *)
				case (1'b1)
					instr_lb[RR] || instr_lbu[RR]: mem_wordsize[RWM] <= 2;
					instr_lh[RR] || instr_lhu[RR]: mem_wordsize[RWM] <= 1;
					instr_lw[RR]: mem_wordsize[RWM] <= 0;
				endcase
				latched_is_lu[EX] <= is_lbu_lhu_lw[RR];
				latched_is_lh[EX] <= instr_lh[RR];
				latched_is_lb[EX] <= instr_lb[RR];
				// if (ENABLE_TRACE) begin
				// 	trace_valid <= 1;
				// 	trace_data <= 0 | TRACE_ADDR | ((reg_op1 + decoded_imm) & 32'hffffffff);
				// end
				next_stage[EX] <= LR_B;
				mem_rden <= 1'b1;
			end
			else if(next_stage[RR]&WM_B && clk_temp[4] && !branch_hit_ex && !instr_trap) begin
				// write mem;
				mem_addr <= reg_op1;
				(* parallel_case, full_case *)
				case (1'b1)
					instr_sb[RR]: mem_wordsize[RWM] <= 2;
					instr_sh[RR]: mem_wordsize[RWM] <= 1;
					instr_sw[RR]: mem_wordsize[RWM] <= 0;
				endcase
				mem_wren <= 1'b1;
				next_stage[EX] <= 0;
				instr_finished[EX] <= 1'b1;
			end 
			else begin
				next_stage[EX] <= next_stage[RR];
			end
			if(instr_trap)
				next_stage[EX] <= 0;
		end
	end

	/** LR: load Register */
	always @(posedge clk or negedge resetn) begin
		if (!resetn) begin
			// reset
			pre_instr_finished_lr <= 1'b0;
			load_reg_lr <= 1'b0;
			cpuregs_write[LR] <= 1'b0;
		end
		else begin
			next_stage[BUB_4] <= next_stage[EX];
			next_stage[BUB_5] <= next_stage[BUB_4];
			reg_out[BUB_4] <= reg_out[EX];
			reg_out[BUB_5] <= reg_out[BUB_4];
			load_reg_lr <= 1'b0;
			//cpuregs_write[LR] = 1'b0;
			if(next_stage[BUB_5] == LR_B && clk_temp[7]) begin
				
				if(latched_is_lu[BUB_5]|latched_is_lh[BUB_5]|latched_is_lb[BUB_5]) begin
					(* parallel_case, full_case *)
					case (1'b1)
						latched_is_lu[BUB_5]: reg_out[LR] <= mem_rdata_word;
						latched_is_lh[BUB_5]: reg_out[LR] <= $signed(mem_rdata_word[15:0]);
						latched_is_lb[BUB_5]: reg_out[LR] <= $signed(mem_rdata_word[7:0]);
					endcase
				end
				else begin
					reg_out[LR] <= reg_out[BUB_5];
				end
				pre_instr_finished_lr <= !branch_instr[BUB_5];
				load_reg_lr <= 1'b1;
				//cpuregs_write[LR] = 1'b1;
			end
			else if(instr_finished[BUB_5] && clk_temp[7]) begin
				pre_instr_finished_lr <= 1'b1;
				load_reg_lr <= 1'b0;
			end
			else begin
				pre_instr_finished_lr <= 1'b0;
				load_reg_lr <= 1'b0;
			end
		end
	end



endmodule
