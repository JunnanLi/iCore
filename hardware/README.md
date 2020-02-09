# hardware
hardware文件夹包含13个文件：
1) TuMan_core.v:  10级流水RISCV核（[TuMan](https://github.com/JunnanLi/TuMan)）
2) TuMan_top.v:   CPU核顶层文件，连接CPU核和存储器
3) memory.v:      存储器，包含指令存储器（即ITCM）和数据存储器（即DTCM）
4) conf_mem.v:    配置模块，通过报文配置ITCM和DTCM，其中以太网协议字段为0x9001-0x9004，以及输出程序中的"printf"内容，以太网协议字段为0x9005 
5) um_for_cpu.v:  项目为CPU建立的顶层文件，包含CPU核顶层和配置CPU的模块，即TuMan_top.v和conf_mem.v 
6) parser_pkt.v:  报文解析，解析TCP报文并送给报文处理模块，即manage_pkt.v
7) manage_pkt.v:  报文处理，将报文缓存进RAM，待CPU处理完报文后，从RAM读取报文，并输出
8) um_for_pktPipeline.v:  项目为pipeline建立的顶层文件，包含解析和报文处理模块，即parser_pkt.v和manage_pkt.v
9) um.v:          项目的顶层模块，接口定义参见[FAST开源项目](http://www.fastswitch.org/), 负责从网口接收报文，以及向网口发送报文
10) gen_data_fixed_instr.sv:  指令静态存储, 根据FAST报文格式生成以太网报文，用于配置存储器，即ITCM and DTCM。供仿真使用
11) testbench_for_iCore.v:   项目的测试激励，供仿真使用
12) gen_data_instr.sv:  配合write_instr.py，以及firmware.hex生成gen_data_fixed_instr.sv。供仿真使用
13) write_instr.py:  配合gen_data_instr.sv.py，以及firmware.hex生成gen_data_fixed_instr.sv。供仿真使用
