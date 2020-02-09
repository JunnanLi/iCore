/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.02
 *	Description: basic packet processing of icore_software. 
 */

#include "basic_pkt_process.h"

//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| offset is the Position in CPU RAM, this program is '0';
//*				| type is ARP_REQ or ARP_RESP;
//*				| srcMAC, srcIP, dstMAC, dstIP are all input;
//*	return		| void	
void send_arp_packet(uint32_t offset, uint32_t type, uint16_t *srcMAC, 
	uint16_t *srcIP, uint16_t *dstMAC, uint16_t *dstIP)
{
	uint32_t *a;
	uint32_t pkt[16] = {0xffffffff, 0xffff0000, 0x00000000, 0x08060001,
						0x08000604, 0x00010000, 0x00000000, 0xcac50f81,
						0x00000000, 0x00000000, 0x00000000, 0,0,0,0,0};
	uint32_t meta[4] = {74, 0, 0, 3};
	int i;

	if(type == ARP_REQ){
		pkt[1] = pkt[1] | (uint32_t) srcMAC[0];
		pkt[2] = ((uint32_t)srcMAC[1]<<16) | (uint32_t) srcMAC[2];
		pkt[5] = 0x00010000 | (uint32_t) srcMAC[0];
		pkt[6] = pkt[2];
		pkt[7] = ((uint32_t)srcIP[0]<<16) | (uint32_t) srcIP[1];
		pkt[9] = pkt[9] | (uint32_t) dstIP[0];
		pkt[10] = ((uint32_t) dstIP[1]<<16);
	}
	else{
		pkt[0] = ((uint32_t)dstMAC[0]<<16) | (uint32_t) dstMAC[1];
		pkt[1] = ((uint32_t)dstMAC[2]<<16) | (uint32_t) srcMAC[0];
		pkt[2] = ((uint32_t)srcMAC[1]<<16) | (uint32_t) srcMAC[2];
		pkt[5] = 0x00020000 | (uint32_t) srcMAC[0];
		pkt[6] = pkt[2];
		pkt[7] = ((uint32_t)srcIP[0]<<16) | (uint32_t) srcIP[1];
		pkt[8] = pkt[0];
		pkt[9] = ((uint32_t)dstMAC[2]<<16) | (uint32_t) dstIP[0];
		pkt[10] = ((uint32_t) dstIP[1]<<16);
	}

	a = (uint32_t *)CPU_PKT_BASE_ADDR + 8 + offset;
	for (i = 0; i < 16; ++i){
		*((volatile uint32_t*)a) = pkt[i];
		a++;
	}
	//	set metadata_0;
	a = (uint32_t *)CPU_PKT_BASE_ADDR + offset;
	for (i = 0; i < 4; ++i){
		*((volatile uint32_t*)a) = meta[i];
		a++;
	}
	print_str("Send arp!\n");
	return;
}

//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| dstMAC, dstIP are all input;
//*	return		| packet type (ARP_REQ or ARP_RESP), srcMAC, srcIP;
int recv_arp_packet(uint16_t *srcMAC, uint16_t *srcIP, uint16_t *dstMAC, 
	uint16_t *dstIP)
{
	uint32_t *a;
	a = (uint32_t *)PKT_BASE_ADDR;
	//	check packet in packet RAM;
	struct eth_hdr *ethHdr = (struct eth_hdr *)(a+5);
	struct arp_hdr *arpHdr = (struct arp_hdr *)(ethHdr->payload);
	struct arp_ipv4 *arpIPv4 = (struct arp_ipv4 *)(arpHdr->data);
	// compare dstIP and eth type, and return srcMAC, srcIP, arp type;
	if(ethHdr->ethertype == 0x0806 && ethHdr->hwtype_ipvl == 0x1 &&
		arpIPv4->dip_0 == dstIP[0] && arpIPv4->dip_1 == dstIP[1])
	{
		// get srcMAC and srcIP
		srcMAC[0] = ethHdr->smac_0;
		srcMAC[1] = ethHdr->smac_1;
		srcMAC[2] = ethHdr->smac_2;
		srcIP[0] = arpIPv4->sip_0;
		srcIP[1] = arpIPv4->sip_1;
		*((volatile uint32_t*)a) = 4;
		if(arpHdr->opcode == ARP_REQ){
			print_str("Recv ARP-Req, and send ARP-Resp!\n");
			//	return ARP-respond; 
			send_arp_packet(0, ARP_RESP, dstMAC, dstIP, srcMAC, srcIP);
			return ARP_REQ;
		}
		else{
			print_str("Recv ARP-Resp!\n");
			return ARP_RESP;
		}
	}
#ifdef PRINT_TEST
	print_str("eth_type: ");
	print_hex(ethHdr->ethertype,4);
	print_str("\narp type: ");
	print_hex(arpHdr->opcode,4);
	print_str("\ndstIP: ");
	print_hex(arpIPv4->dip_0,4);
	print_hex(arpIPv4->dip_1,4);
	print_str("\n============\n");
#endif
	return -1;
}

//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| offset is the Position in CPU RAM;
//*				| type is ICMP_REQ or ICMP_RESP;
//*				| srcMAC, srcIP, dstMAC, dstIP are all input;
//*	return		| void;
void send_icmp_packet(uint32_t offset, uint32_t type, uint16_t *srcMAC, 
	uint16_t *srcIP, uint16_t *dstMAC, uint16_t *dstIP)
{
	uint32_t *a;
	uint32_t pkt[28] = {0x00000000, 0x00000000, 0x00000000, 0x08004500,
						0x00542baf, 0x40004001, 0x5a6c0000, 0x00000000,
						0x00000800, 0xf961500b, 0x0001bdd4, 0x365e0000,
						0x0000f28b, 0x09000000, 0x00001011, 0x12131415,
						0x16171819, 0x1a1b1c1d, 0x1e1f2021, 0x22232425,
						0x26272829, 0x2a2b2c2d, 0x2e2f3031, 0x32333435,
						0x36370000, 0x00000000, 0x00000000, 0x00000000};
	uint32_t meta[4] = {130, 0, 0, 3};

	if(type == ICMP_REQ){
		int i;
		// dstMAC[0] = dstMAC[0];
		// srcMAC[0] = srcMAC[0];
		// dstIP[0] = dstIP[0];
		// srcIP[0] = srcIP[0];
		pkt[0] = ((uint32_t)dstMAC[0]<<16) | (uint32_t) dstMAC[1];
		pkt[1] = ((uint32_t)dstMAC[2]<<16) | (uint32_t) srcMAC[0];
		pkt[2] = ((uint32_t)srcMAC[1]<<16) | (uint32_t) srcMAC[2];
		// pkt[7] = ((uint32_t)srcIP[1]<<16) | (uint32_t) dstIP[0];	//0x0f81cac5
		pkt[6] = pkt[6] | (uint32_t)srcIP[0];
		pkt[7] = ((uint32_t)srcIP[1]<<16) | (uint32_t) dstIP[0];
		pkt[8] = pkt[8] | ((uint32_t)dstIP[1]<<16);					//0x0f820800
		print_hex(pkt[8],8);
		

		a = (uint32_t *)CPU_PKT_BASE_ADDR + 8 + offset;
		for (i = 0; i < 28; ++i){
			*((volatile uint32_t*)a) = pkt[i];
			a++;
		}
		//	set metadata_0;
		a = (uint32_t *)CPU_PKT_BASE_ADDR + offset;
		for (i = 0; i < 4; ++i){
			*((volatile uint32_t*)a) = meta[i];
			a++;
		}
		print_str("send icmp req successfully\n");
		return;
	}
	else{
		//	TODO:
		print_str("Return icmp resp successfully!\n");
	}
}


//***********************************************************************
//*	function	| send arp packet;
//*	parameter	| dstMAC, dstIP are all input;
//*	return		| packet type (ICMP_REQ or ICMP_RESP;), srcMAC, srcIP;
int recv_icmp_packet(uint16_t *srcMAC, uint16_t *srcIP, uint16_t *dstMAC, 
	uint16_t *dstIP)
{
	uint32_t *a;
	a = (uint32_t *)PKT_BASE_ADDR;

	struct eth_hdr *ethHdr = (struct eth_hdr *)(a+5);
	struct ip_hdr *ipHdr = (struct ip_hdr *)(ethHdr->payload);
	// struct icmp_v4 *icmpV4 = (struct icmp_v4 *)(ipHdr->data);
	// compare dstMAC, eth_type, protocol, icmp_type;
	if(ethHdr->dmac_0 == dstMAC[0] && ethHdr->dmac_1 == dstMAC[1] && 
		ethHdr->dmac_2 == dstMAC[2] && ethHdr->ethertype == 0x0800 &&
		ipHdr->proto == 1)
	{
		uint16_t type = ipHdr->type_code_sport;
		// get srcMAC and srcIP
		srcMAC[0] = ethHdr->smac_0;
		srcMAC[1] = ethHdr->smac_1;
		srcMAC[2] = ethHdr->smac_2;
		uint32_t temp_11 = *((volatile uint32_t*)a + 11) & 0xffff0000;
		srcIP[0] = ipHdr->saddr_0;
		srcIP[1] = ipHdr->saddr_1;
		if(type == 0x0800){
			print_str("recv icmp req!\n");
			//	send_back_icmp, 5-7 is dmac&smac, 11-12 is sip&dip;
			*((volatile uint32_t*)a + 5) = ((uint32_t)srcMAC[0]<<16) | (uint32_t) srcMAC[1];
			*((volatile uint32_t*)a + 6) = ((uint32_t)srcMAC[2]<<16) | (uint32_t) dstMAC[0];
			*((volatile uint32_t*)a + 7) = ((uint32_t)dstMAC[1]<<16) | (uint32_t) dstMAC[2];
			*((volatile uint32_t*)a + 11) = temp_11 | (uint32_t)dstIP[0];
			*((volatile uint32_t*)a + 12) = ((uint32_t)dstIP[1]<<16) | (uint32_t) srcIP[0];
			*((volatile uint32_t*)a + 13) = (uint32_t)srcIP[1]<<16;
			// print_hex(srcIP[1],8);

			/**	calculate checksum*/
			uint16_t icmp_cksum = 0;
			uint32_t length = (( (*((volatile uint32_t*)a + 9)) >> 16) - 20)>>1;
			uint32_t len_32 = (( (*((volatile uint32_t*)a + 9)) >> 16) - 20)>>2;
			// print_str("length = "); print_dec(length); print_str("\n");
			if((length&0x1) == 0){
				uint32_t temp_last = *((volatile uint32_t*)a + 13+ len_32);
					*((volatile uint32_t*)a + 13+ len_32) = temp_last & 0xffff0000;
			}
			// clear previous checksum;
			*((volatile uint32_t*)a + 14) = (*((volatile uint32_t*)a + 14)) & 0x0000ffff;
			uint16_t *pkt_16b = (uint16_t *) (a+14);
			
			icmp_cksum  = cal_checksum(pkt_16b, length);
			*((volatile uint32_t*)a + 14) = (*((volatile uint32_t*)a + 14)) | 
				((uint32_t)icmp_cksum)<<16;
			*((volatile uint32_t*)a) = 3;
		}
		else{
			print_str("recv icmp resp!\n");
			*((volatile uint32_t*)a) = 4;
		}
		return (int) type;
	}
#ifdef PRINT_TEST
	print_str("\nnot a icmp pkt\n");
	print_hex(ethHdr->dmac_0, 4);
	print_hex(ethHdr->dmac_1, 4);
	print_hex(ethHdr->dmac_2, 4);
	print_str("\neth_type: ");
	print_hex(ethHdr->ethertype, 4);
	print_str("\nprotocol: ");
	print_hex(ipHdr->proto,2);
	print_str("\nicmp_type: ");
	print_hex(ipHdr->type_code_sport,8);
	print_str("\n============\n");
#endif
	return -1;
}

//***********************************************************************
//*	function	| recv tcp or udp packet;
//*	parameter	| dstMAC, dstIP, dstPort are all input;
//*	return		| packet type (TCP or UDP), srcMAC, srcIP;
int recv_tcp_udp_packet(uint16_t *dstMAC, uint16_t *dstIP, uint16_t *dstPort){
	uint32_t *addr;
	addr = (uint32_t *)PKT_BASE_ADDR;
	struct eth_hdr *ethHdr = (struct eth_hdr *)(addr+5);
	struct ip_hdr *ipHdr = (struct ip_hdr *)(ethHdr->payload);
	struct tcp_hdr *tcpHdr = (struct tcp_hdr *)(ipHdr->data);

	// compare dstMAC, eth_type, protocol, dstIP, dstPort;
	// if(ethHdr->dmac_0 == dstMAC[0] && ethHdr->dmac_1 == dstMAC[1] && 
	// 	ethHdr->dmac_2 == dstMAC[2] && ethHdr->ethertype == 0x0800 &&
	// 	ipHdr->proto == 6 && ipHdr->daddr_1 == dstIP[1] && tcpHdr->dport == *dstPort)
	if(ethHdr->dmac_0 == dstMAC[0] && ethHdr->dmac_1 == dstMAC[1] && 
		ethHdr->dmac_2 == dstMAC[2] && ethHdr->ethertype == 0x0800 && 
		ipHdr->daddr_1 == dstIP[1] && tcpHdr->dport == *dstPort)
	{
		if(ipHdr->proto == 6){
			// print_str("recv tcp\n");
			return (int) (((tcpHdr->flags) & 0x1f) + TYPE_OFFSET);
		}
		else
			return TYPE_UDP;
	}
#ifdef PRINT_TEST
	print_str("dmac: ");
	print_hex(ethHdr->dmac_0,4);
	print_hex(ethHdr->dmac_1,4);
	print_hex(ethHdr->dmac_2,4);
	print_str("\neth_type: ");
	print_hex(ethHdr->ethertype,4);
	print_str("\nproto: ");
	print_hex(ipHdr->proto,4);
	print_str("\ndstIP: ");
	print_hex(ipHdr->daddr_1,4);
	print_str("\ndstPort: ");
	print_hex(tcpHdr->dport,4);
	print_str("\n*dstPort: ");
	print_hex(*dstPort,4);
	print_str("\nbitmap: ");
	print_dec(ethHdr->dmac_0 == dstMAC[0]);
	print_dec(ethHdr->dmac_1 == dstMAC[1]);
	print_dec(ethHdr->dmac_2 == dstMAC[2]);
	print_dec(ethHdr->ethertype == 0x0800);
	print_dec(ipHdr->proto == 6);
	print_dec(ipHdr->daddr_1 == dstIP[1]);	
	print_dec(tcpHdr->dport == *dstPort);
	print_str("\n============\n");
#endif
	return -1;
}

//***********************************************************************
//*	function	| recv packet bu calling recv_arp/icmp/tcp_udp_packet();
//*	parameter	| dstMAC, dstIP, dstPort are all input;
//*	return		| packet type, srcMAC, srcIP;
int recv_packet(uint16_t *srcMAC, uint16_t *srcIP, uint16_t *dstMAC, 
	uint16_t *dstIP, uint16_t *dstPort)
{
	/**	check packet type: */
	//	1) arp request: remote -> host; and if we recv ARP-req packet,
	//		 we will return ARP-resp packet;
	int type = recv_arp_packet(srcMAC, srcIP, dstMAC, dstIP);
	if(type != -1)
		return type;
	
	//	2) icmp request: hremote -> host; and if we recv icmp req packet, 
	//		 we will return icmp resp packet;
	type = recv_icmp_packet(srcMAC, srcIP, dstMAC, dstIP);
	if(type != -1)
		return type;

	type = recv_tcp_udp_packet(dstMAC, dstIP, dstPort);

	return type;
}

//***********************************************************************
//*	function	| switch packet without any modification;
void discard_packet(uint32_t *addr){
	if(*((volatile uint32_t*)addr) == 1){
#ifdef PRINT_TEST
		print_str("discard packet\n");
		for (int i = 0; i < 4; ++i){
			print_hex(*(addr+5+i),8);
		}
		print_str("\n");
		for (int i = 0; i < 4; ++i){
			print_hex(*(addr+9+i),8);
		}
		print_str("\n");
		for (int i = 0; i < 4; ++i){
			print_hex(*(addr+13+i),8);
		}
		print_str("\n================\n");
#endif
		*((volatile uint32_t*)addr) = 4;
	}
}

//***********************************************************************
//*	function	| discard packet
//*	parameter	| addr is the location of metadata[31:0];
void switch_packet(void){
	uint32_t *a;
	// struct eth_hdr *ethHdr;
	// struct arp_hdr *arpHdr;
	// struct arp_ipv4 *arpIPv4;
	//	1st to 12nd packet;
	a = (uint32_t *)PKT_BASE_ADDR;
	if(*((volatile uint32_t*)a) == 1){
#ifdef PRINT_TEST		
		ethHdr = (struct eth_hdr *)(a+5);
		arpHdr = (struct arp_hdr *)(ethHdr->payload);
		arpIPv4 = (struct arp_ipv4 *)(arpHdr->data);
		print_str("test eth_hdr struct\nethHdr->dmac: ");
		print_hex(ethHdr->dmac_0, 4);
		print_hex(ethHdr->dmac_1, 4);
		print_hex(ethHdr->dmac_2, 4);
		print_str("\nethHdr->smac: ");
		print_hex(ethHdr->smac_0, 4);
		print_hex(ethHdr->smac_1, 4);
		print_hex(ethHdr->smac_2, 4);
		print_str("\nethHdr->ethertype: ");
		print_hex(ethHdr->ethertype, 4);
		
		print_str("\nethHdr->hwtype_ipvl: ");
		print_hex(ethHdr->hwtype_ipvl, 4);
		print_str("\narpHdr->protype: ");
		print_hex(arpHdr->protype, 4);
		print_str("\narpHdr->hwsize: ");
		print_hex(arpHdr->hwsize, 2);
		print_str("\narpHdr->prosize: ");
		print_hex(arpHdr->prosize, 2);
		print_str("\narpHdr->opcode: ");
		print_hex(arpHdr->opcode, 4);
		
		print_str("\narpHdr->smac: ");
		print_hex(arpHdr->smac_0, 4);
		print_hex(arpIPv4->smac_1, 4);
		print_hex(arpIPv4->smac_2, 4);
		print_str("\narp_ipv4->sip: ");
		print_hex(arpIPv4->sip_0, 4);
		print_hex(arpIPv4->sip_1, 4);
		print_str("\narp_ipv4->dmac: ");
		print_hex(arpIPv4->dmac_0, 4);
		print_hex(arpIPv4->dmac_1, 4);
		print_hex(arpIPv4->dmac_2, 4);
		print_str("\narp_ipv4->dip: ");
		print_hex(arpIPv4->dip_0, 4);
		print_hex(arpIPv4->dip_1, 4);
#endif
		*((volatile uint32_t*)a) = 3;
		print_str("send\n");
	}
}



//***********************************************************************
//*	function	| calculation checksum
//*	parameter	| data is 16-bit array, size is the number of member;
uint16_t cal_checksum(uint16_t *data, int size){
	uint32_t cksum = 0;
	for (int i = 0; i < size; i++){
		cksum += data[i];
#ifdef PRINT_TEST
		print_str("\ndata: ");
		print_hex(data[i],8);
		print_str("\tcksum: ");
		print_hex(cksum,8);
#endif
	}
	uint16_t checksum_temp = (uint16_t ) (cksum&0xFFFF) + (uint16_t ) (cksum >>16);
	return ~checksum_temp;
}