/*
 *  Basic functions of FreeRTOS_on_Tuman32.
 *	Hardware ISA is based on RV-32I, OS Kernel is based on FreeRTOS V10.3.0
 *
 *	Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>. All Rights Reserved.
 *	Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.02
 *	Description: basic processing. 
 *	1 tab == 4 spaces!
 */

#ifndef FIRMWARE_H
#define FIRMWARE_H

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

//*	Address of RAM in pipeline
#define PKT_BASE_ADDR 0x8000000c		// metadata[31:0] in pkt RAM;
#define CPU_PKT_BASE_ADDR 0x80000800	// initial addr of CPU RAM;
//* Special address in iCore
#define OUTPORT 0x10000000				// print address
#define DISPLAY_IN_VERILOG 0x10000001	// DISPLAY_IN_VERILOG address
#define TIMER_INSTR_OFFSET 0x20000000	// initial addr of system timer/instr
#define TIMER_L_ADDR 0x20000100			// system timer address
#define TIMER_H_ADDR 0x20000104			
#define TIMERCMP_L_ADDR 0x20000108		// system timer address
#define TIMERCMP_H_ADDR 0x2000010c			
// #define INSTR_ADDR 0x20000002			// system instruction counter address
#define TEMP_M0 0x20000004
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
void print_void(void);

void sys_gettime(struct timespec *timer);
// int sys_getinstr(void);

// functions in mainFreeRtos
void mainFreeRTOS(void);
void schedulerForSsie(void);
void schedulerForStie(void);
void progForSIE(void);

// end function
void sys_finish(void);

#endif
