/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.02
 *	Description: basic processing of icore_software. 
 */

#include "firmware.h"


//* print funciton;
//*	1) print a char; 2) print a string;
//* 3) print a dec; 4) print a hex;
void print_chr(char ch){
	*((volatile uint32_t*)OUTPORT) = ch;
}

void print_str(const char *p){
	while (*p != 0)
		*((volatile uint32_t*)OUTPORT) = *(p++);
}

void print_dec(unsigned int val){
	char buffer[10];
	char *p = buffer;
	while (val || p == buffer) {
		*(p++) = val % 10;
		val = val / 10;
	}
	while (p != buffer) {
		*((volatile uint32_t*)OUTPORT) = '0' + *(--p);
	}
}

void print_hex(unsigned int val, int digits){
	for (int i = (4*digits)-4; i >= 0; i -= 4)
		*((volatile uint32_t*)OUTPORT) = "0123456789ABCDEF"[(val >> i) % 16];
}

//* memory processing funciton;
void *memcpy(char* dst0, char *src0, int len0){
	char *dst = (char *) dst0;
	const char *src = (char *) src0;
	while (len0--){
		*dst++ = *src++;	
	}
	return dst0;
}

void* memset(void* s, int c, uint32_t n){
	unsigned char* p = (unsigned char*) s;

	while(n > 0){
		*p++ = (unsigned char) c;
		n--;
	}
	return s;
}

//* read system timer or instruction counter
void sys_gettime(struct timespec *timer){
	uint32_t *addr = (uint32_t *) TIMER_H_ADDR;
	timer->tv_sec = *((volatile uint32_t*)addr);
	timer->tv_nsec = *((volatile uint32_t*)addr+1);
}

// int sys_getinstr(void){
// 	uint32_t *addr = (uint32_t *) INSTR_ADDR;
// 	return(*((volatile uint32_t*)addr));
// }

// end function
void sys_finish(void){
	print_str("Finish!\n");
	uint32_t *addr;
	addr = (uint32_t *) FINISH_ADDR;
	*((volatile uint32_t*)addr) = 1;
}