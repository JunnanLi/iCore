#include "send_recv.h"

void send_packet(struct send_ctx *sendCtx)
{

	char err_buf[100] = "";
	libnet_t *lib_net = NULL;
	libnet_ptag_t lib_t = 0;
	unsigned char src_mac[6] = {0x00,0x01,0x02,0x03,0x04,0x05};
	unsigned char dst_mac[6] = {0x06,0x07,0x08,0x09,0x0a,0x0b};
	    
      
	lib_net = libnet_init(LIBNET_LINK_ADV, "enp0s31f6", err_buf);
	
	
	if(NULL == lib_net)  
	{  
	    perror("libnet_init");  
	    exit(-1);  
	}  


	// set sel = 1;
	lib_t = libnet_build_ethernet(
		(u_int8_t *)dst_mac,  
		(u_int8_t *)src_mac,  
		sendCtx->type,
		(u8 *) &(sendCtx->payload),	// payload 
		sendCtx->lens,  		// payload length
		lib_net,  
		0  
	);  

	int res = 0;  
	res = libnet_write(lib_net);
	if(-1 == res)  
	{  
	    perror("libnet_write");  
	    exit(-1);  
	}

	libnet_destroy(lib_net);     
	printf("----ok-----\n");
} 

void set_read_sel(int read, u32 value){
	struct send_ctx *sendCtx;
	sendCtx = (struct send_ctx *)malloc(sizeof(struct send_ctx));
	if(read == 1)
		sendCtx->type = 0x9002;
	else
		sendCtx->type = 0x9001;

	struct one_128b *one128b = &(sendCtx->payload.one128b[0]);
	one128b->pad = htonl(0);
	one128b->itcm_data = htonl(0);
	one128b->dtcm_data = htonl(0);
	one128b->addr = htonl(value);
	sendCtx->lens = 16;
	send_packet(sendCtx);
}

void write_tcm(char *fileName, int lineNum){
	FILE * fp;
	if((fp = fopen(fileName,"r")) == NULL){
		perror("fail to read");
		exit (1) ;
	}

	u32	data;
	int i;
	for(i=0; i<lineNum; i++){
		fscanf(fp,"%08x\n", &data);
	}

	struct send_ctx *sendCtx;
	sendCtx = (struct send_ctx *)malloc(sizeof(struct send_ctx));
	struct one_128b *one128b;
	for (i=0; i<50; i++){
		fscanf(fp,"%08x\n", &data);
		one128b = &(sendCtx->payload.one128b[i]);
		one128b->pad = htonl(0);
		one128b->itcm_data = htonl(0);
		one128b->dtcm_data = htonl(data);
		one128b->addr = htonl(lineNum+i);
	}

	sendCtx->type = 0x9003;

	sendCtx->lens = 800;
	send_packet(sendCtx);

	fclose(fp);
}



void read_tcm(int lineNum){
	struct send_ctx *sendCtx;
	sendCtx = (struct send_ctx *)malloc(sizeof(struct send_ctx));
	struct one_128b *one128b = &(sendCtx->payload.one128b[0]);
	one128b->pad = htonl(0);
	one128b->itcm_data = htonl(0);
	one128b->dtcm_data = htonl(0);
	one128b->addr = htonl(lineNum);
	sendCtx->type = 0x9004;
	sendCtx->lens = 16;
	send_packet(sendCtx);
}



 
void send_tcp_pkt(){
    libnet_t *handle; /* Libnet句柄 */
    int packet_size; /* 构造的数据包大小 */
    char *device = "enp0s31f6"; /* 设备名字,也支持点十进制的IP地址,会自己找到匹配的设备 */
    char *src_ip_str = "192.168.2.148"; /* 源IP地址字符串 */
    char *dst_ip_str = "192.168.2.170"; /* 目的IP地址字符串 */
    u_char src_mac[6] = {0x00, 0x0c, 0x29, 0xba, 0xee, 0xdd}; /* 源MAC */
    u_char dst_mac[6] = {0x00, 0x0c, 0x29, 0x6d, 0x4d, 0x5c}; /* 目的MAC */
    u_long dst_ip, src_ip; /* 网路序的目的IP和源IP */
    char error[LIBNET_ERRBUF_SIZE]; /* 出错信息 */
    libnet_ptag_t eth_tag, ip_tag, tcp_tag, tcp_op_tag; /* 各层build函数返回值 */
    u_short proto = IPPROTO_TCP; /* 传输层协议 */
    u_char payload[255] = {0}; /* 承载数据的数组，初值为空 */
    u_long payload_s = 0; /* 承载数据的长度，初值为0 */
 
    /* 把目的IP地址字符串转化成网络序 */
    dst_ip = libnet_name2addr4(handle, dst_ip_str, LIBNET_RESOLVE);
    /* 把源IP地址字符串转化成网络序 */
    src_ip = libnet_name2addr4(handle, src_ip_str, LIBNET_RESOLVE);
 
    /* 初始化Libnet */
    if ( (handle = libnet_init(LIBNET_LINK, device, error)) == NULL ) {
        printf("libnet_init failure\n");
        exit;
    }
 
    strncpy(payload, "test", sizeof(payload)-1); /* 构造负载的内容 */
    payload_s = strlen(payload); /* 计算负载内容的长度 */
 
 
    tcp_tag = libnet_build_tcp(
                30330,                    /* 源端口 */
                30331,                    /* 目的端口 */
                8888,                    /* 序列号 */
                8889,                    /* 确认号 */
                TH_PUSH | TH_ACK,        /* Control flags */
                14600,                    /* 窗口尺寸 */
                0,                        /* 校验和,0为自动计算 */
                0,                        /* 紧急指针 */
                LIBNET_TCP_H + payload_s, /* 长度 */
                payload,                    /* 负载内容 */
                payload_s,                /* 负载内容长度 */
                handle,                    /* libnet句柄 */
                0                        /* 新建包 */
    );
    if (tcp_tag == -1) {
        printf("libnet_build_tcp failure\n");
        exit;
    }
 
    /* 构造IP协议块，返回值是新生成的IP协议快的一个标记 */
    ip_tag = libnet_build_ipv4(
        LIBNET_IPV4_H + LIBNET_TCP_H + payload_s, /* IP协议块的总长,*/
        0, /* tos */
        (u_short) libnet_get_prand(LIBNET_PRu16), /* id,随机产生0~65535 */
        0, /* frag 片偏移 */
        (u_int8_t)libnet_get_prand(LIBNET_PR8), /* ttl,随机产生0~255 */
        proto, /* 上层协议 */
        0, /* 校验和，此时为0，表示由Libnet自动计算 */
        src_ip, /* 源IP地址,网络序 */
        dst_ip, /* 目标IP地址,网络序 */
        NULL, /* 负载内容或为NULL */
        0, /* 负载内容的大小*/
        handle, /* Libnet句柄 */
        0 /* 协议块标记可修改或创建,0表示构造一个新的*/
    );
    if (ip_tag == -1) {
        printf("libnet_build_ipv4 failure\n");
       	exit;
    }
 
    /* 构造一个以太网协议块,只能用于LIBNET_LINK */
    eth_tag = libnet_build_ethernet(
        dst_mac, /* 以太网目的地址 */
        src_mac, /* 以太网源地址 */
        ETHERTYPE_IP, /* 以太网上层协议类型，此时为IP类型 */
        NULL, /* 负载，这里为空 */ 
        0, /* 负载大小 */
        handle, /* Libnet句柄 */
        0 /* 协议块标记，0表示构造一个新的 */ 
    );
    if (eth_tag == -1) {
        printf("libnet_build_ethernet failure\n");
        exit;
    }
 
    packet_size = libnet_write(handle); /* 发送已经构造的数据包*/
 
    libnet_destroy(handle); /* 释放句柄 */

    printf("success\n");
 
}