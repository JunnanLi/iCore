#include "send_recv.h"





int main(int argc, char *argv[])
{
	int opt;
	int i;
	while(1){
		printf("//======================================================//\n");
		printf("\tPlease chose your option:\n");
		printf("\t0:\tset sel to 0, i.e., running mode\n");
		printf("\t1:\tset sel to 1, i.e., configuring mode\n");
		printf("\t2:\tread sel\n");
		printf("\t3:\tconfigure instruction\n");
		printf("\t4:\tread instruction\n");
		printf("//======================================================//\n");
		printf("opt is: ");
		scanf("%d", &opt);

		if(opt == 0)
			set_read_sel(0, 0);
		else if(opt == 1)
			set_read_sel(0, 1);
		else if(opt == 2)
			set_read_sel(1, 0);
		else if(opt == 3){
			char fileName[20] = "firmware.hex";
			int lineNum = 0;
			for (i = 0; i < 20; i++){
				lineNum = 50*i;
				write_tcm(fileName, lineNum);
			}
		}
		else if(opt == 4){
			for (i = 0; i < 1000; i++){
				read_tcm(i);
			}
		}
		else if(opt == 5){
			send_tcp_pkt();
		}
		

		
	}

    return 0;
} 
