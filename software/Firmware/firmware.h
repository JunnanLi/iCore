/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.02
 *	Description: basic processing. 
 */

#ifndef FIRMWARE_H
#define FIRMWARE_H

#include <stdint.h>
#include <stdbool.h>

//*	Address of RAM in pipeline
#define PKT_BASE_ADDR 0x8000000c		// metadata[31:0] in pkt RAM;
#define CPU_PKT_BASE_ADDR 0x80000800	// initial addr of CPU RAM;
//* Special address in iCore
#define OUTPORT 0x10000000				// print address
#define TIMER_INSTR_OFFSET 0x20000000	// initial addr of system timer/instr
#define TIMER_H_ADDR 0x20000000			// system timer address
#define TIMER_L_ADDR 0x20000001			
// #define INSTR_ADDR 0x20000002			// system instruction counter address
#define FINISH_ADDR 0xF0000000			// stop program when writing this
										//	address;
//*	some struct
struct timespec{
	uint32_t tv_sec;
	uint32_t tv_nsec;
};



//*	for test mode
// #define PRINT_TEST

//*	some basic function for iCore;
//* print funciton;
//*	1) print a char; 2) print a string;
//* 3) print a dec; 4) print a hex;
void print_chr(char ch);
void print_str(const char *p);
void print_dec(unsigned int val);
void print_hex(unsigned int val, int digits);
//* memory processing funciton;
void* memcpy(char* dst0, char *src0, int len0);
void* memset(void* s, int c, uint32_t n);
//* read system timer or instruction counter
void sys_gettime(struct timespec *timer);
// int sys_getinstr(void);
// main function: tuman_program
void tuman_program(void);
// end function
void sys_finish(void);

#endif
