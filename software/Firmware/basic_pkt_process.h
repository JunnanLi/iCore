/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.02
 *	Description: basic packet processing of icore_software. 
 */

#ifndef BASIC_PKT_PROCESS_H
#define BASIC_PKT_PROCESS_H

#include "firmware.h"
#include "packet_format.h"
//*	some basic function for packet processing;


//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| offset is the Position in CPU RAM;
//*				| type is ARP_REQ or ARP_RESP;
//*				| srcMAC, srcIP, dstMAC, dstIP are all input;
//*	return		| void	
void send_arp_packet(uint32_t offset, uint32_t type, uint16_t *srcMAC, 
	uint16_t *srcIP, uint16_t *dstMAC, uint16_t *dstIP);

//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| dstMAC, dstIP are all input;
//*	return		| packet type (ARP_REQ or ARP_RESP), srcMAC, srcIP;
int recv_arp_packet(uint16_t *srcMAC, uint16_t *srcIP, uint16_t *dstMAC, 
	uint16_t *dstIP);

//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| offset is the Position in CPU RAM;
//*				| type is ICMP_REQ or ICMP_RESP;
//*				| srcMAC, srcIP, dstMAC, dstIP are all input;
//*	return		| void;
void send_icmp_packet(uint32_t offset, uint32_t type, uint16_t *srcMAC, 
	uint16_t *srcIP, uint16_t *dstMAC, uint16_t *dstIP);


//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| dstMAC, dstIP are all input;
//*	return		| packet type (ICMP_REQ or ICMP_RESP;), srcMAC, srcIP;
int recv_icmp_packet(uint16_t *srcMAC, uint16_t *srcIP, uint16_t *dstMAC, 
	uint16_t *dstIP);

//***********************************************************************
//*	function	| recv tcp or udp packet;
//*	parameter	| dstMAC, dstIP, dstPort are all input;
//*	return		| packet type (TCP or UDP), srcMAC, srcIP;
int recv_tcp_udp_packet(uint16_t *dstMAC, uint16_t *dstIP, uint16_t *dstPort);

//***********************************************************************
//*	function	| recv packet bu calling recv_arp/icmp/tcp_udp_packet();
//*	parameter	| dstMAC, dstIP, dstPort are all input;
//*	return		| packet type, srcMAC, srcIP;
int recv_packet(uint16_t *srcMAC, uint16_t *srcIP, uint16_t *dstMAC, 
	uint16_t *dstIP, uint16_t *dstPort);

//***********************************************************************
//*	function	| switch packet without any modification;
void switch_packet(void);

//***********************************************************************
//*	function	| discard packet
//*	parameter	| addr is the location of metadata[31:0];
void discard_packet(uint32_t *addr);

//***********************************************************************
//*	function	| calculation checksum
//*	parameter	| data is 16-bit array, size is the number of member;
uint16_t cal_checksum(uint16_t *data, int size);


#endif
