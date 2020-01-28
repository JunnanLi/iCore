# Controller
## Files
There are 5 files in this folder:

| File name   | Function description |
|-------------|----------------------|
| send_recv.h | Header file          |
| sendPacket.c|Used to send Ethernet packet (0x9001-0x9004) to configure Core leveraging libpcap, 0x9001 is used to start program; 0x9002 is used to read cpu state (pause or start); 0x9003 is used to load program; 0x9004 is used to read program loade in CPU |
|sender_test.c| Has a main function used to configure Core          |
|recvPacket.c | Used to receive Ehternet packet returned from CPU, 0x9002 is state; 0x9004 is program loade in CPU; 0x9005 is "printf" in running program          |
|receive_test.c| Has a main function used to print information returned from CPU          |

## Usage
1) Run Makefile (i.e., `make` ) to generate two binary program, i.e., t_send & t_recv
2) Run t_send (i.e., `./t_send`) to configure CPU, you will see a simplied UI, And you can chose any option by inputing the corresponding digit：
  >>//======================================================//  
>>  Please chose your option:  
>>	0:	set sel to 0, i.e., running mode  
>>	1:	set sel to 1, i.e., configuring mode  
>>	2:	read sel  
>>	3:	configure instruction  
>>	4:	read instruction  
>>//======================================================//  
>>  opt is:  

    For example,  we run the example program by inputing `3` to configure intstuction, and then `0` to run the program  
3) Run t_recv (i.e., `./t_recv`) to print values returned from CPU， you will see two kinds of returned value:  
a) dtcm_sel is `x`, e.g., `dtcm_sel is 0` in running mode  
b) `printf value`, e.g., `Hello, AoTuman!` in our example
