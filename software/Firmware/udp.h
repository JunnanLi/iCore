/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.02
 *	Description: udp packet processing of icore_software. 
 */

#ifndef UDP_H
#define UDP_H

#include "firmware.h"
#include "packet_format.h"
#include "basic_pkt_process.h"
#include "udp.h"

//****************************************************************
//*	function	| send tcp packet;
//*	parameter	| sock, data, size are all output;
//*	return		| return '-1' if it is fail to send;
int send_udp_packet(struct icore_sock * sock, char *data, int size);

//****************************************************************
//*	function	| wait tcp packet;
//*	parameter	| sock is input;
//*	return		| received data, length and cli_addr;
int wait_udp_packet(struct icore_sock * sock, char *data, 
	struct icore_sockaddr * cli_addr);

//****************************************************************
//*	function	| bind server addr;
//*	parameter	| sock , serv_addr are input;
//*	return		| '-1' if it fail to bind;
int bind_serv(struct icore_sock * sock, struct icore_sockaddr * serv_addr);

//****************************************************************
//*	function	| send udp data;
//*	parameter	| sock, data, size, and serv_addr are input;
//*	return		| '-1' if it fail to bind;
int sendto(struct icore_sock * sock, char *data, int size, 
	struct icore_sockaddr * serv_addr);

//****************************************************************
//*	function	| recv udp data;
//*	parameter	| sock, data, and size are input;
//*	return		| return len, data and cli_addr;
int recvfrom(struct icore_sock * sock, char *data, int size,
	struct icore_sockaddr * cli_addr);

#endif