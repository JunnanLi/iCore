/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.07
 *	Description: tcp packet processing of icore_software. 
 */


#include "tcp.h"
#include "udp.h"

//***********************************************************************
//*	function	| send tcp packet;
//*	parameter	| sock, type, data, size are all input;
//*	return		| return '-1' if it is fail to send;
int send_tcp_packet(struct icore_sock * sock, uint32_t type, char *data, 
	int size){
	//*	we should guarantee that previous packet has been sent;
	uint32_t *addr;
	addr = (uint32_t *)CPU_PKT_BASE_ADDR + 3;
	while(*((volatile uint32_t*)addr) != 0){}
	//*	initial packet array;
	//*	TODO: replace DMAC;
	uint32_t pkt[100] = {0x8c164549, 0x25ac8c16, 0x45492501, 0x00004500,
						0x002c2707, 0x40004006, 0x0000cac5, 0x0f810000,
						0x00000000, 0x00000000, 0x00000000, 0x00006000,
						0xfaf00000, 0x00000204, 0x05b40000, 0x00000000,
						0x00000000, 0x00000000, 0x00000000, 0x00000000,
						0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
						0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
						0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
						0,0,0,0,0};
	//*	initial metadata array;
	uint32_t meta[4] = {90, 0, 0, 3};	// 102, 86;
	int i;
	uint16_t ip_csum;
	int tcp_csum_len;	// length of data for calc. tcp checksum in 16b;

	//*	rewrite packet, including dip, ip_checksum;
	//*	TODO: get dmac using arp;
	struct eth_hdr *ethHdr = (struct eth_hdr *)(pkt);
	struct ip_hdr *ipHdr = (struct ip_hdr *)(pkt+4);
	struct tcp_hdr *tcpHdr = (struct tcp_hdr *)(ipHdr->data);

	ipHdr->daddr_0 = sock->sockAddr.dip[0];
	ipHdr->daddr_1 = sock->sockAddr.dip[1];
	ipHdr->id = ipHdr->id + (uint16_t) (sock->id);
	sock->id = sock->id + 1;
	ipHdr->len = ipHdr->len + (uint16_t) size;
	meta[0] = meta[0] + size;
	ip_csum = cal_checksum((uint16_t *)(pkt+3), 12);

	//*	calculate tcp checksum for handshaking or transmit packets;
	//*	we should guarantee data[size,size+1,size+2,size+3] = 0;
	// data[size] = 0;data[size+1] = 0;data[size+2] = 0;data[size+3] = 0;
	if(size != 0){
		tcpHdr->pad = ((uint16_t)data[0])<<8 | ((uint16_t)data[1]);
		i=2;
		int offset_32 = 0;
		while(i < size){
			*((tcpHdr->data) +offset_32) = (((uint32_t)data[i])<<24) | 
				(((uint32_t)data[i+1])<<16) | (((uint32_t)data[i+2])<<8) |
				(((uint32_t)data[i+3]));
			i += 4;
			offset_32++;
		}
		pkt[5] = 0x00180006 + (((uint32_t) size)<<16);
		tcp_csum_len = 20 + (size>>1);	
	}
	else{
		pkt[5] = 0x00180006;
		tcp_csum_len = 20;
	}
	//*	rewrite packet, including sport, dport, seq, ack_seq, flags, 
	//*	tcp checksum;
	ipHdr->type_code_sport = sock->sockAddr.sport;
	tcpHdr->dport = sock->sockAddr.dport;
	tcpHdr->seq_0 = sock->send_seq[0];
	tcpHdr->seq_1 = sock->send_seq[1];
	tcpHdr->ack_0 = sock->ack_seq[0];
	tcpHdr->ack_1 = sock->ack_seq[1];
	tcpHdr->flags = tcpHdr->flags | (uint16_t)type;
	tcpHdr->csum = cal_checksum((uint16_t *)(pkt+5), tcp_csum_len);

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
	// noted: must keey this print, I do not konw why currently. However, 
	//	packet has been egressed to FPGA_OS, but hasn't been transmitted;
	print_str("");

	return 0;
}


//***********************************************************************
//*	function	| wait tcp packet;
//*	parameter	| sock, wait_type are input;
//*	return		| received data and length;
int wait_tcp_ack(struct icore_sock * sock, uint32_t wait_type, char *data){
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
			if(((uint32_t)type & 0x10000017) == (wait_type | 0x10000000)){
				
				//*	calculate data length in tcp;
				struct ip_hdr *ipHdr = (struct ip_hdr *)(addr+9);
				struct tcp_hdr *tcpHdr = (struct tcp_hdr *)(addr+14);
				int tcpHdr_len_32 = (int)((tcpHdr->flags)>>12);
				int data_len = (int)(ipHdr->len) - (int)((tcpHdr->flags)>>10) -20;
#ifdef PRINT_TEST				
				print_str("recv waited tcp packet!\n");
				print_str("\ndata_length: ");
				print_hex(data_len,8);
				print_str("\ntcpHdr_len_32");
				print_hex(tcpHdr_len_32,8);
				print_str("\n");
#endif
				//*	obtain data: from little-endian to big-endian;
				if(data_len != 0){
					char *tcpData = (char *)(addr +14 +tcpHdr_len_32); 
					data[0] = *(tcpData-3);
					data[1] = *(tcpData-4);
					int i = 2;
					while(i < data_len){
						data[i] = *(tcpData +i +1);
						data[i+1] = *(tcpData +i);
						data[i+2] = *(tcpData +i -1);
						data[i+3] = *(tcpData +i -2);
						i += 4;
					}
#ifdef PRINT_TEST
					print_str("\ndata: ");
					for (int i = 0; i < (data_len-2); ++i){
						print_hex(*(tcpData +i),2);
					}
#endif
				}

				//*	update ack_seq;
				if((type & (TCP_SYN | TCP_FIN)) != 0)
					data_len = 1;
				uint32_t low_ack = (uint32_t)(tcpHdr->seq_1) +(uint32_t)data_len;
				uint32_t actual_ack = (((uint32_t)(tcpHdr->seq_0))<<16) + low_ack;
				sock->ack_seq[0] = (uint16_t)(actual_ack>>16);
				sock->ack_seq[1] = (uint16_t)(actual_ack & 0x0000ffff);
				//*	update send_seq;
				sock->send_seq[0] = tcpHdr->ack_0;
				sock->send_seq[1] = tcpHdr->ack_1;
				if(type == TYPE_TCP_SYN){
					sock->sockAddr.dport = ipHdr->type_code_sport;
					sock->send_seq[0] = 0x1234;
					sock->send_seq[1] = 0x5678;
				}
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
//*	function	| initial sock;
//*	parameter	| sock, wait_type are all input;
//*	return		| void
void sock(struct icore_sock * sock, int type){
	sock->type = type;
	sock->state = TCP_CLOSED;
	sock->id = 0;
	sock->send_seq[0] = 0x5602;
	sock->send_seq[1] = 0x6cbe;
	sock->ack_seq[0] = 0;
	sock->ack_seq[1] = 0;
	sock->sockAddr.smac[0] = ICORE_MAC_0;
	sock->sockAddr.smac[1] = ICORE_MAC_1;
	sock->sockAddr.smac[2] = ICORE_MAC_2;
	sock->sockAddr.sport = ICORE_STREAM_PORT;
	sock->sockAddr.sip[0] = ICORE_IP_0;
	sock->sockAddr.sip[1] = ICORE_IP_1;
}


//***********************************************************************
//*	function	| establish tcp connection with remote host;
//*	parameter	| sock, serv_addr are all input;
//*	return		| void
void connect(struct icore_sock * sock, struct icore_sockaddr * serv_addr){
	//* TODO: obtain the dstMAC by sending ARP packets;
	sock->sockAddr.dport = serv_addr->dport;
	sock->sockAddr.dip[0] = serv_addr->dip[0];
	sock->sockAddr.dip[1] = serv_addr->dip[1];
	//* TODO: obtain dstMac by ARP;
	sock->sockAddr.dmac[0] = 0x8c16;
	sock->sockAddr.dmac[1] = 0x4549;
	sock->sockAddr.dmac[2] = 0x25ac;
	//*	send syn;
	char data[2];	// fake data;
	send_tcp_packet(sock, TCP_SYN, data, 0);
	//*	wait syn-ack;
	wait_tcp_ack(sock, (uint32_t)(TCP_SYN | TCP_ACK), data);
	//*	send ack;
	send_tcp_packet(sock, TCP_ACK, data, 0);
}

//***********************************************************************
//*	function	| bind sock with serv_addr;
//*	parameter	| sock, serv_addr are all input;
//*	return		| void
void bind(struct icore_sock * sock, struct icore_sockaddr * serv_addr){
	sock->sockAddr.sport = serv_addr->sport;
	sock->sockAddr.sip[0] = serv_addr->sip[0];
	sock->sockAddr.sip[1] = serv_addr->sip[1];
}

//***********************************************************************
//*	function	| listen connection request from remote host;
//*	parameter	| sock, num are all input;
//*	return		| void
void listen(struct icore_sock * sock, int num){
	char data[2];	// fake data;
	//	wait syn;
	wait_tcp_ack(sock, TCP_SYN, data);
	//	send syn-ack;
	send_tcp_packet(sock, (TCP_ACK|TCP_SYN), data, 0);
// #ifdef
	print_dec(num);
// #endif
}

//***********************************************************************
//*	function	| accept connection request from remote host;
//*	parameter	| sock_serv is input;
//*	return		| return sock_cli
void accept(struct icore_sock * sock_serv, struct icore_sock * sock_cli){
	char data[2];	// fake data;
	//	wait ack;
	wait_tcp_ack(sock_serv, TCP_ACK, data);
	//	construct sock_cli;
	sock_cli->type = sock_serv->type;
	sock_cli->state = sock_serv->state;
	sock_cli->send_seq[0] = sock_serv->send_seq[0];
	sock_cli->send_seq[1] = sock_serv->send_seq[1];
	sock_cli->ack_seq[0] = sock_serv->ack_seq[0];
	sock_cli->ack_seq[1] = sock_serv->ack_seq[1];
	sock_cli->id = sock_serv->id;
	sock_cli->sockAddr.dmac[0] = sock_serv->sockAddr.dmac[0];
	sock_cli->sockAddr.dmac[1] = sock_serv->sockAddr.dmac[1];
	sock_cli->sockAddr.dmac[2] = sock_serv->sockAddr.dmac[2];
	sock_cli->sockAddr.dport = sock_serv->sockAddr.dport;
	sock_cli->sockAddr.dip[0] = sock_serv->sockAddr.dip[0];
	sock_cli->sockAddr.dip[1] = sock_serv->sockAddr.dip[1];
	sock_cli->sockAddr.smac[0] = sock_serv->sockAddr.smac[0];
	sock_cli->sockAddr.smac[1] = sock_serv->sockAddr.smac[1];
	sock_cli->sockAddr.smac[2] = sock_serv->sockAddr.smac[2];
	sock_cli->sockAddr.sport = sock_serv->sockAddr.sport;
	sock_cli->sockAddr.sip[0] = sock_serv->sockAddr.sip[0];
	sock_cli->sockAddr.sip[1] = sock_serv->sockAddr.sip[1];
}

//***********************************************************************
//*	function	| send data by calling send_tcp_packet;
//*	parameter	| sock, data, size are all input;
//*	return		| return '-1' if it is fail to send;
int write(struct icore_sock * sock, char *data, int size){
	if(sock->type == TCP_STREAM){
		send_tcp_packet(sock, TCP_ACK, data, size);
		wait_tcp_ack(sock, TCP_ACK, data);
	}
	else
		send_udp_packet(sock, data, size);
	return 0;
}

//***********************************************************************
//*	function	| read data by calling wait_tcp_ack;
//*	parameter	| sock, size are input;
//*	return		| return data and data length;
int read(struct icore_sock * sock, char *data, int size){
	int len = 0;
	if(sock->type == TCP_STREAM){
		len = wait_tcp_ack(sock, TCP_ACK, data);
		//*	send back ack;
		send_tcp_packet(sock, TCP_ACK, data, 0);
	}
	else{
		struct icore_sockaddr cli_addr;	// fake cli_addr;
		len = wait_udp_packet(sock, data, &cli_addr);
	}
	if(size > len)
		return len;
	else
		return size;
}

//***********************************************************************
//*	function	| close socket;
//*	parameter	| sock is input;
//*	return		| void;
void close(struct icore_sock * sock){
	if(sock->type == TCP_STREAM){
		//	send fin;
		char data[2];	// fake data;
		send_tcp_packet(sock, TCP_FIN | TCP_ACK, data, 0);
		//	wait fin-ack;
		wait_tcp_ack(sock, (uint32_t)(TCP_FIN | TCP_ACK), data);
		//	send ack;
		send_tcp_packet(sock, TCP_ACK, data, 0);
	}
	//*	TODO: recycle memory
}