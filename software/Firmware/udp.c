/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.08
 *	Description: udp packet processing of icore_software. 
 */

#include "udp.h"


//***********************************************************************
//*	function	| send tcp packet;
//*	parameter	| sock, data, size are all output;
//*	return		| return '-1' if it is fail to send;
int send_udp_packet(struct icore_sock * sock, char *data, int size){
	//* TODO: obtain the dstMAC by ARP
	//*	we should guarantee that previous packet has been sent;
	uint32_t *addr;
	addr = (uint32_t *)CPU_PKT_BASE_ADDR + 3;
	while(*((volatile uint32_t*)addr) != 0){}
	//*	initial packet array;
	//*	TODO: replace DMAC;
	uint32_t pkt[100] = {0x8c164549, 0x25ac8c16, 0x45492501, 0x00004500,
						0x001c2707, 0x40004011, 0x0000cac5, 0x0f810000,
						0x00000000, 0x00000000, 0x00000000, 0x00000000,
						0x00000000, 0x00000000, 0x00000000, 0x00000000,
						0x00000000, 0x00000000, 0x00000000, 0x00000000,
						0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
						0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
						0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
						0,0,0,0,0};
	//*	initial metadata array;
	uint32_t meta[4] = {74, 0, 0, 3};	// 102, 86;
	int i;
	uint16_t ip_csum;
	int udp_csum_len;	// length of data for calc. tcp checksum in 16b;

	//*	rewrite packet, including dip, ip_checksum;
	//*	TODO: get dmac using arp;
	struct eth_hdr *ethHdr = (struct eth_hdr *)(pkt);
	struct ip_hdr *ipHdr = (struct ip_hdr *)(pkt+4);
	struct udp_hdr *udpHdr = (struct udp_hdr *)(ipHdr->data);

	ipHdr->daddr_0 = sock->sockAddr.dip[0];
	ipHdr->daddr_1 = sock->sockAddr.dip[1];
	ipHdr->id = ipHdr->id + (uint16_t) (sock->id);
	sock->id = sock->id + 1;
	ipHdr->len = ipHdr->len + (uint16_t) size;
	meta[0] = meta[0] + size;
	ip_csum = cal_checksum((uint16_t *)(pkt+3), 12);

	//*	calculate udp checksum for handshaking or transmit packets;
	udpHdr->data_pad = ((uint16_t)data[0])<<8 | ((uint16_t)data[1]);
	i=2;
	int offset_32 = 0;
	while(i < size){
		*((udpHdr->data) +offset_32) = (((uint32_t)data[i])<<24) | 
			(((uint32_t)data[i+1])<<16) | (((uint32_t)data[i+2])<<8) |
			(((uint32_t)data[i+3]));
		i += 4;
		offset_32++;
	}
	pkt[5] = 0x00080011 + (((uint32_t) size)<<16);
	udp_csum_len = 16 + (size>>1);

	//*	rewrite packet, including sport, dport, len, udp checksum;
	ipHdr->type_code_sport = sock->sockAddr.sport;
	udpHdr->dport = sock->sockAddr.dport;
	udpHdr->len = (uint16_t)(8 + size);
	udpHdr->csum = cal_checksum((uint16_t *)(pkt+5), udp_csum_len);

	//*	reconstruct ip header;
	ipHdr->flags = 0x4000;
	ipHdr->csum = ip_csum;
	ipHdr->ttl = 0x40;
	//*	reconstruct ethernet header;
	ethHdr->ethertype = 0x0800;
	
	//	write packet array to CPU RAM in pipeline;
	addr = (uint32_t *)CPU_PKT_BASE_ADDR + 8;
	for (i = 0; i < 100; ++i){
		*((volatile uint32_t*)addr) = pkt[i];
		addr++;
	}
	//	write metadata 0 to CPU RAM in pipeline;
	addr = (uint32_t *)CPU_PKT_BASE_ADDR;
	for (i = 0; i < 4; ++i){
		*((volatile uint32_t*)addr + i) = meta[i];
		// addr += 1;
	}
	// print_str("Send a tcp pkt!\n");
	// noted: must keey this print, I have do not konw why currently;
	print_str("");

	return 0;
}


//***********************************************************************
//*	function	| wait tcp packet;
//*	parameter	| sock is input;
//*	return		| received data, length and cli_addr;
int wait_udp_packet(struct icore_sock * sock, char *data, 
	struct icore_sockaddr * cli_addr)
{
	int type;
	//*	check PKT_RAM in hardware pipeline;
	//*	TODO: change "while(1)" to wait for x ms;
	uint32_t * addr = (uint32_t *)PKT_BASE_ADDR;
	while(1){
		if(*((volatile uint32_t*)addr) == 1){
			//*	recv packet, and obtain packet type;
			type = recv_packet(sock->sockAddr.dmac, sock->sockAddr.dip, 
				sock->sockAddr.smac, sock->sockAddr.sip, 
				&(sock->sockAddr.sport) );
#ifdef PRINT_TEST			
			print_str("\ntcp_type: ");
			print_hex(type,8);
			print_str("\n");
#endif			
			//*	compare type with wait_type
			if(((uint32_t)type) == TYPE_UDP){
				struct ip_hdr *ipHdr = (struct ip_hdr *)(addr+9);
				struct udp_hdr *udpHdr = (struct udp_hdr *)(addr+14);
				//*	obtain srcIP, port info
				cli_addr->dport = ipHdr->type_code_sport;
				cli_addr->dip[0] = ipHdr->saddr_0;
				cli_addr->dip[1] = ipHdr->saddr_1;

				//*	calculate data length in udp;
				int data_len = (int)(udpHdr->len) -8;
#ifdef PRINT_TEST				
				print_str("recv waited tcp packet!\n");
				print_str("\ndata_length: ");
				print_hex(data_len,8);
				print_str("\ntcpHdr_len_32");
				print_hex(tcpHdr_len_32,8);
				print_str("\n");
#endif
				//*	obtain data: from little-endian to big-endian;

				char *udpData = (char *)(addr +16); 
				data[0] = *(udpData-3);
				data[1] = *(udpData-4);
				int i = 2;
				while(i < data_len){
					data[i] = *(udpData +i +1);
					data[i+1] = *(udpData +i);
					data[i+2] = *(udpData +i -1);
					data[i+3] = *(udpData +i -2);
					i += 4;
				}
#ifdef PRINT_TEST
				print_str("\ndata: ");
				for (i = 0; i < (data_len-2); ++i){
					print_hex(*(udpData +i),2);
				}
#endif

				//*	noted: we also discard this packet in PKT RAM;
				discard_packet(addr);
				return data_len;
			}
			//*	discard current packet in PKT RAM;
			discard_packet(addr);
		}
	}
}

//***********************************************************************
//*	function	| bind server addr;
//*	parameter	| sock and serv_addr are input;
//*	return		| '-1' if it fail to bind;
int bind_serv(struct icore_sock * sock, struct icore_sockaddr * serv_addr){
	sock->sockAddr.dport = serv_addr->dport;
	sock->sockAddr.dip[0] = serv_addr->dip[0];
	sock->sockAddr.dip[1] = serv_addr->dip[1];
	// TODO: obtain dstMac by ARP;
	sock->sockAddr.dmac[0] = 0x8c16;
	sock->sockAddr.dmac[0] = 0x4549;
	sock->sockAddr.dmac[0] = 0x25ac;
	return 1;
}

//***********************************************************************
//*	function	| send data;
//*	parameter	| sock, data, size, and serv_addr are input;
//*	return		| '-1' if it fail to bind;
int sendto(struct icore_sock * sock, char *data, int size, 
	struct icore_sockaddr * serv_addr)
{
	bind_serv(sock, serv_addr);
	if(size > 1)
		send_udp_packet(sock, data, size);
	else
		return -1;
	//*	TODO: check serv_addr;
	serv_addr->dport = serv_addr->dport;
	return 0;
}

//***********************************************************************
//*	function	| recv udp data;
//*	parameter	| sock, data and size are input;
//*	return		| return len, data and cli_addr;
int recvfrom(struct icore_sock * sock, char *data, int size,
	struct icore_sockaddr * cli_addr)
{
	int len = wait_udp_packet(sock, data, cli_addr);
	if(size > len)
		return len;
	else
		return size;
}
