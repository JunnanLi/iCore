/*
 *  iCore_software -- Software for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.02.01
 *	Description: Main function of icore_software. 
 */

#include "firmware.h"
#include "packet_format.h"
#include "basic_pkt_process.h"
#include "tcp.h"
#include "udp.h"

void tuman_program(void){
	/**	running test, including x functions*/

	/**	Function 1: print "Hello AoTuman!"
	 **/
	// print_str("=================\n");
	// print_str("Hello AoTuman!\n");
	// print_str("=================\n");
	
	/**	Function 2: L2 switching (L2SW). Now, we support receieving one 
	 **	 packet from x port, then loopbacking to x port.
	 **/
	// switch_packet();
	
	/** Function 3: Ping (ICMP) from each side. 
	 **	1) recv ARP request packet, return an ARP-respond packet;
	 **	2) recv ICMP request pkt, return an ICMP-respond packet;
	 **	3) send ARP request packet, wait an ARP-respond packet;
	 **	4) send ICMP request pkt, wait an ICMP-respond packet;
	 **/
	// u16 hostMAC[3] = {0x8c16, 0x4549, 0x2501};
	// u16 hostIP[2] = {0xcac5, 0x0f81};
	// u16 remoteMAC[3] = {0x8c16, 0x4549, 0x25ac};
	// u16 remoteIP[2] = {0xcac5, 0x0f82};
	// uint32_t *addr;
	// while(1){
	// 	addr = (uint32_t *)PKT_BASE_ADDR;
	// 	//*	check packet in packet RAM;
	// 	if(*((volatile uint32_t*)addr) == 1){
	// 		//*	1) arp request: remote -> host; and if we recv arp req 
	// 		//*		packet, we will return arp resp packet; 
	// 		recv_arp_packet(remoteMAC, remoteIP, hostMAC, hostIP);

	// 		//*	2) icmp request: hremote -> host; and if we recv icmp 
	// 		//*		req packet, we will return icmp resp packet; 
	// 		recv_icmp_packet(remoteMAC, remoteIP, hostMAC, hostIP);
			
	// 		//*	discard other packets
	// 		discard_packet(addr);
	// 	}
	// 	/****************************/
	// 	/**	TODO: ping from iCore; **/
	// 	/****************************/
	// }



	/**	Function 4: Communication with TCP (from iCore to remote host)
	 **	1) initial icore_sock struct;
	 **	2) connet to dstIP (handshake with remote host);
	 **	3) read/write data;
	 **	4) close icore_socket;
	 **/
	//	//*	1) initial sock struct
	// struct icore_sock tcpSock;
	// struct icore_sockaddr serv_addr;
	// serv_addr.dip[0] = 0xcac5;
	// serv_addr.dip[1] = 0x0f82;
	// serv_addr.dport = 5001;

	// sock(&tcpSock, TCP_STREAM);
	// 	//*	2) connet to dstIP(send syn, wait syn-ack, send ack)
	// connect(&tcpSock, &serv_addr);

	//	//*	3) read/write data
	// char message[40] = "Hi, I'm AoTuman!\n";
	// write(&tcpSock, message, 20);
	// int len_rd = read(&tcpSock, message, 20);
	
	// print_str("\nMessage from server: ");
	// message[len_rd] = 0;
	// print_str(message);

	//	//*	4) close tcp socket **/
	// close(&tcpSock);

	//	//*	tcp connection request from another side
	//	//*	1) initial sock struct **/
	// struct icore_sock tcpSock_serv, tcpSock_cli;
	// struct icore_sockaddr serv_addr;
	// serv_addr.sip[0] = ICORE_IP_0;
	// serv_addr.sip[1] = ICORE_IP_1;
	// serv_addr.sport = ICORE_STREAM_PORT;

	// sock(&tcpSock_serv, TCP_STREAM);
	//	/**	2) accept connet request from remote host (wait syn, recv 
	//   **	 syn-ack, wait ack) 
	//   **/
	// bind(&tcpSock_serv, &serv_addr);
	// //*	TODO: listen more client
	// listen(&tcpSock_serv, 1);
	// accept(&tcpSock_serv, &tcpSock_cli);

	//	//*	4) read/write data
	// char message_recv[40];
	// char message_send[40] = "Hi, I'm AoTuman!\n";

	// int len_rd = read(&tcpSock_cli, message_recv, 20);
	// print_str("\nMessage from server: ");
	// message_recv[len_rd] = 0;
	// print_str(message_recv);
	// write(&tcpSock_cli, message_send, 20);

	//	//*	5) close tcp socket
	// close(&tcpSock_cli);



	/**	Function 5: communicating with UDP;
	 **	1) initial icore_sock struct;
	 **	2) read/write data;
	 ** 3) close udp socket;
	 **/
	//*	1) initial sock struct
	struct icore_sock udpSock;
	struct icore_sockaddr servAddr, cliAddr;
	servAddr.dip[0] = 0xcac5;
	servAddr.dip[1] = 0x0f82;
	servAddr.dport = 6001;
	
	sock(&udpSock, UDP_STREAM);

	//*	2) read/write data **/
	//*	we should guarantee message[size+] = 0;
	char message[40] = "Hi, I'm AoTuman!\n";
	sendto(&udpSock, message, 20, &servAddr);  
	int len_rd = recvfrom(&udpSock, message, 20, &cliAddr);
	print_str("\nMessage from server: ");
	message[len_rd] = 0;
	print_str(message);

	//*	3) close udp socket **/
	close(&udpSock);

	//*	we also support that icore as a udp server;
	//	//*	1) initial sock struct
	// struct icore_sock udpSock;
	// struct icore_sockaddr cliAddr;
	// sock(&udpSock, UDP_STREAM);

	//	//*	2) read/write data **/
	//	//*	we should guarantee message[size+] = 0;
	// char message[40] = "Hi, I'm AoTuman!\n";
	// int len_rd = recvfrom(&udpSock, message, 20, &cliAddr);
	// print_str("\nMessage from server: ");
	// message[len_rd] = 0;
	// print_str(message);

	// sendto(&udpSock, message, 20, &cliAddr);
	//	//*	3) close udp socket **/
	// close(&udpSock);



	/**	Function 6: test array*/
	// uint32_t array[10]={0x0,0x1,0x2,0x3,0x4,0x5,0x6,0x7,0x8,0x9};
	// for (int i = 0; i < 10; i++){
	// 	print_str("\n");
	// 	print_dec(array[i]);
	// }
	// print_str("\n");

	/**	Function 7: test sys_gettime()*/
	// struct timespec time_now;
	// sys_gettime(&time_now);
	// print_str("\ntime: ");
	// print_dec(time_now.tv_sec);
	// print_str("\t: ");
	// print_dec(time_now.tv_nsec);
	// print_str("\n");


	sys_finish();
}






	






