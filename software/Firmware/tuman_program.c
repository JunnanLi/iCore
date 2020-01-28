// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include "firmware.h"
#define PKT_BASE_ADDR 0x8000000c

/**program for testing lines of empty program */
void tuman_program(void){
	print_str("Hello Tuman\n");
	int *a;
	int i;
	while(1){
		//	1st packet;
		a = (int *)PKT_BASE_ADDR;
		for(i=0; i<12; i++){
			if(*a == 1){
				*a = 3;
			}
			a = a + 512;
		}
	}
}






	





