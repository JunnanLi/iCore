/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.07
 *	Description: tcp packet processing of icore_software. 
 */

#ifndef TCP_H
#define TCP_H

#include "firmware.h"
#include "packet_format.h"
#include "basic_pkt_process.h"

// TODO: maintain TCP state
#define TCP_CLOSED 0


//************************************************************
//*	function	| send tcp packet;
//*	parameter	| sock, type, data, size are all output;
//*	return		| return '-1' if it is fail to send;
int send_tcp_packet(struct icore_sock * sock, uint32_t type, 
	char *data, int size);

//************************************************************
//*	function	| wait tcp packet;
//*	parameter	| sock, wait_type are all output;
//*	return		| received data and length;
int wait_tcp_ack(struct icore_sock * sock, uint32_t wait_type, 
	char *data);

//************************************************************
//*	function	| initial sock;
//*	parameter	| sock, type are all input;
//*	return		| void
void sock(struct icore_sock * sock, int type);

//************************************************************
//*	function	| establish tcp connection with remote host;
//*	parameter	| sock, serv_addr are all input;
//*	return		| void
void connect(struct icore_sock *  sock, struct icore_sockaddr * serv_addr);

//************************************************************
//*	function	| bind sock with serv_addr;
//*	parameter	| sock, serv_addr are all input;
//*	return		| void
void bind(struct icore_sock * sock, struct icore_sockaddr * serv_addr);

//************************************************************
//*	function	| listen connection request from remote host;
//*	parameter	| sock, num are all input;
//*	return		| void
void listen(struct icore_sock * sock, int num);

//************************************************************
//*	function	| accept connection request from remote host;
//*	parameter	| sock_serv is input;
//*	return		| return sock_cli
void accept(struct icore_sock * sock_serv, struct icore_sock * sock_cli);

//************************************************************
//*	function	| send data by calling send_tcp_packet;
//*	parameter	| sock, data, size are all input;
//*	return		| return '-1' if it is fail to send;
int write(struct icore_sock * sock, char *data, int size);

//************************************************************
//*	function	| read data by calling wait_tcp_ack;
//*	parameter	| sock, size are input;
//*	return		| return data and data length;
int read(struct icore_sock * sock, char *data, int size);

//************************************************************
//*	function	| close socket;
//*	parameter	| sock is input;
//*	return		| void;
void close(struct icore_sock * sock);


#endif