#include "send_recv.h"


void get_packet(unsigned char *argument, const struct pcap_pkthdr *p_pkthdr, const unsigned char *packet_content){
	
	// printf("type is %02x%02x\n", packet_content[12], packet_content[13]);
	if((packet_content[12] == 0x90)&&(packet_content[13] == 0x05)){
		printf("%c", (char) packet_content[29]);
	}
	else if((packet_content[12] == 0x90)&&(packet_content[13] == 0x02)){
		printf("dtcm_sel is %d\n", packet_content[29]);
	}
	else if((packet_content[12] == 0x90)&&(packet_content[13] == 0x04)){
		printf("itcm data is %02x%02x%02x%02x\n", packet_content[18],packet_content[19],packet_content[20],packet_content[21]);
		printf("dtcm data is %02x%02x%02x%02x\n", packet_content[22],packet_content[23],packet_content[24],packet_content[25]);
		printf("addr is %02x%02x%02x%02x\n", packet_content[26],packet_content[27],packet_content[28],packet_content[29]);
	}
}


void recv_print_value(){
	int recvPktPID=0;


	pcap_t * pcap_h = NULL;  
	char error_content[100] = "";
	const unsigned char *packet = NULL;
	char *p_net_interface_name = NULL;
	struct pcap_pkthdr p_pkthdr;

	p_net_interface_name = pcap_lookupdev(error_content);  
	if(NULL == p_net_interface_name) {  
		perror("pcap_lookupdev");  
		exit(-1);  
	}  
	printf("interface: %s\n", p_net_interface_name); 

	pcap_h = pcap_open_live(p_net_interface_name,BUFSIZE,0,0,error_content);
	if(pcap_h == NULL){
		printf("error_pcap_handle\n");
		exit(0);
	}

	//BPF filter;
	// struct bpf_program filter;
	// pcap_compile(pcap_h, &filter, "ehter dst 00:01:02:03:04:05", 1, 0);
	
	// pcap_setfilter(pcap_h, &filter);

	
	if(pcap_loop(pcap_h,-1,get_packet,NULL)<0){
		
		perror("pcap_next");
		exit(-1);
	}
  
    pcap_close(pcap_h);
	
} 



