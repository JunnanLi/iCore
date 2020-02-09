/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.02
 *	Description: basic packet format. 
 */

#ifndef PACKET_FORMAT_H
#define PACKET_FORMAT_H

//*	packet type
#define ARP_REQ 1						// arp request;
#define ARP_RESP 2						// arp respond;
#define ICMP_REQ 0x0800					// icmp request;
#define ICMP_RESP 0						// icmp respond;
#define TCP_STREAM 0					// TCP;
#define UDP_STREAM 1					// UDP;
#define TYPE_OFFSET 0x10000000			// To distinguish TCP packet, returned 
#define TYPE_TCP_FIN 0x10000001			//  by recv_packet()
#define TYPE_TCP_SYN 0x10000002			
#define TYPE_TCP_RSR 0x10000004			
#define TYPE_TCP_PUSH 0x10000008		
#define TYPE_TCP_ACK 0x10000010			
#define TYPE_UDP 0x20000000				// To distinguish UDP packet
#define TCP_FIN 1						// TCP flags;
#define TCP_SYN 2						
#define TCP_RSR 4						
#define TCP_PUSH 8						
#define TCP_ACK 16						

//*	some fixed info. of icore
#define ICORE_MAC_0 0x8c16				// MAC address
#define ICORE_MAC_1 0x4549				
#define ICORE_MAC_2 0x2501				
#define ICORE_IP_0 0xcac5				// IP address
#define ICORE_IP_1 0x0f81				
#define ICORE_STREAM_PORT 0xaf51		// port for TCP/UDP

//*	some defination of headers; as we do not want to copy packet 
//*	from RAM in pipeline to RAM belong to CPU, some fields are placed
//*	in previous header, such as hwtype_ipvl is in ehternet hader;
struct eth_hdr{
	uint16_t dmac_1;
	uint16_t dmac_0;
	uint16_t smac_0;
	uint16_t dmac_2;
	uint16_t smac_2;
	uint16_t smac_1;
	uint16_t hwtype_ipvl;
	uint16_t ethertype;
	uint16_t payload[];
} __attribute__((packed));

struct arp_hdr{
	unsigned char prosize;
	unsigned char hwsize;
	uint16_t protype;
	uint16_t smac_0;
	uint16_t opcode;
	uint16_t data[];
} __attribute__((packed));

struct arp_ipv4{
	uint16_t smac_2;
	uint16_t smac_1;
	uint16_t sip_1;
	uint16_t sip_0;
	uint16_t dmac_1;
	uint16_t dmac_0;
	uint16_t dip_0;
	uint16_t dmac_2;
	uint16_t pad;
	uint16_t dip_1;
} __attribute__((packed));

struct ip_hdr{
	uint16_t id;
	uint16_t len;
	uint8_t proto;
	uint8_t ttl;
	uint16_t flags;
	uint16_t saddr_0;
	uint16_t csum;
	uint16_t daddr_0;
	uint16_t saddr_1;
	uint16_t type_code_sport;
	uint16_t daddr_1;
	uint16_t data[];
} __attribute__((packed));

struct icmp_v4 {
	uint16_t pad;
	uint16_t csum;
	uint16_t data[];
} __attribute__((packed));

struct tcp_hdr {
	uint16_t seq_0;
	uint16_t dport;
	uint16_t ack_0;
	uint16_t seq_1;
	uint16_t flags;
	uint16_t ack_1;
	uint16_t csum;
	uint16_t wins;
	uint16_t MSS_0_data_2B;
	uint16_t urgent;
	uint16_t pad;
	uint16_t MSS_1;
	uint32_t data[];
} __attribute__((packed));

// struct tcp_option {
// 	uint16_t pad;
// 	uint16_t MSS_1;
// }__attribute__((packed));

struct udp_hdr {
	uint16_t len;
	uint16_t dport;
	uint16_t data_pad;
	uint16_t csum;
	uint32_t data[];
} __attribute__((packed));

struct icore_sockaddr{
	uint16_t dmac[3];
	uint16_t dport;
	uint16_t dip[2];
	uint16_t smac[3];
	uint16_t sport;
	uint16_t sip[2];
};

struct icore_sock{
	int type;	// TCP_STREAM or UDP_STREAM;
	int state;
	uint16_t send_seq[2];
	uint16_t ack_seq[2];
	uint32_t id;
	struct icore_sockaddr sockAddr;
};

#endif