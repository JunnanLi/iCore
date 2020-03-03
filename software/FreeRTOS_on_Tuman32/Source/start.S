// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.


#define ENABLE_PRINT

#ifndef ENABLE_QREGS
#  undef ENABLE_RVTST
#endif

// Only save registers in IRQ wrapper that are to be saved by the caller in
// the RISC-V ABI, with the excpetion of the stack pointer. The IRQ handler
// will save the rest if necessary. I.e. skip x3, x4, x8, x9, and x18-x27.
#undef ENABLE_FASTIRQ

// #include "custom_ops.S"

	.section .text
/*	.global irq
	.global sieve
	.global multest
	.global hard_mul
	.global hard_mulh
	.global hard_mulhsu
	.global hard_mulhu
	.global stats*/
	.global mainFreeRTOS
	.global schedulerForSsie
	.global schedulerForStie
	.global progForSIE

reset_vec:
	// no more than 16 bytes here !
//	picorv32_waitirq_insn(zero)
//	picorv32_maskirq_insn(zero, zero)

	// j start


/* Main program
 **********************************/

start:
	/* zero-initialize all registers */

	addi x1, zero, 0
	addi x2, zero, 0
	addi x3, zero, 0
	addi x4, zero, 0
	addi x5, zero, 0
	addi x6, zero, 0
	addi x7, zero, 0
	addi x8, zero, 0
	addi x9, zero, 0
	addi x10, zero, 0
	addi x11, zero, 0
	addi x12, zero, 0
	addi x13, zero, 0
	addi x14, zero, 0
	addi x15, zero, 0
	addi x16, zero, 0
	addi x17, zero, 0
	addi x18, zero, 0
	addi x19, zero, 0
	addi x20, zero, 0
	addi x21, zero, 0
	addi x22, zero, 0
	addi x23, zero, 0
	addi x24, zero, 0
	addi x25, zero, 0
	addi x26, zero, 0
	addi x27, zero, 0
	addi x28, zero, 0
	addi x29, zero, 0
	addi x30, zero, 0
	addi x31, zero, 0

	/* running tests from riscv-tests */


	/* set stack pointer */
	lui sp,(64*1024)>>12

	/* set gp and tp */
	lui gp, %hi(0xdeadbeef)
	addi gp, gp, %lo(0xdeadbeef)
	addi tp, gp, 0


	#ifdef ENABLE_PRINT
	/* call tuman_program code */
	jal ra,mainFreeRTOS
	// jal ra,0x22c
	#endif





	/* print "DONE\n" */
	lui a0,0x10000000>>12
	addi a1,zero,'D'
	addi a2,zero,'O'
	addi a3,zero,'N'
	addi a4,zero,'E'
	addi a5,zero,'\n'

	sw a1,0(a0)
	sw a2,0(a0)
	sw a3,0(a0)
	sw a4,0(a0)
	sw a5,0(a0)

	li a0, 0x20000000
	li a1, 123456789
	sw a1,0(a0)

#ifdef MODIFIED_BY_LJN	
#endif
	/* trap */
	ebreak


.type genInterrupt,@function
	
progForSIE:
	addi sp,sp,-8
	sw a1, 4(sp)		// store a1;
	li a1, 0x20000008
	sw ra, 0(a1)		// store ra in MEM1
	sw a2, 8(a1)		// store a2 in MEM3
	lw a2, 4(sp)		// load a1
	sw a2, 4(a1)		// store a1 in MEM2
	addi sp,sp,8
	sw sp, 12(a1)		// store a1 in MEM4

	csrr a1,scause		// read scause
	li a2,0x80000005	// STIE
	bne a1,a2, schedulerForSsie
	j schedulerForStie	
	
	// lw ra, 4(sp)
	// addi sp,sp,8
	// ret

abc:
	li a1,0x10000001
	sw ra,0(a1)
	csrwi sip, 0
	sret