#include <stdio.h> 
#include <pcap.h> 
#include <arpa/inet.h> 
#include <time.h> 
#include <stdlib.h> 
#include <string.h> 
#include <unistd.h>
#include <libnet.h>
#include <pthread.h>

#define BUFSIZE 1514

#ifndef SEND_RECV_H__
#define SEND_RECV_H__

typedef unsigned short u16;
typedef unsigned char u8;
typedef unsigned int u32;


struct one_128b{
	u32 pad;
	u32 itcm_data;
	u32 dtcm_data;
	u32 addr;
};

struct context{
	struct one_128b one128b[50];
};

struct send_ctx{
	u16 type;
	int lens;
	struct context payload;
};



void set_read_sel(int read, u32 value);
void write_tcm(char *fileName, int lineNum);
void read_tcm(int lineNum);
void recv_packet(int num, char *bpf_recv_s);
void send_packet(struct send_ctx *sendCtx);

void recv_print_value();

void send_tcp_pkt();

#endif
