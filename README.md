# iCore项目
in-line FPGA-CPU协同分组处理

## 目录
  * [icore硬件部分](#硬件部分)

## 硬件部分
### 组成
硬件文件夹包含11个文件，功能如下表所示

| 文件名                 | 功能描述 |
|-----------------------|----------------------|
| TuMan_core.v          |  10级流水RISCV核（[TuMan](https://github.com/JunnanLi/TuMan)） |
| TuMan_top.v           |  CPU核顶层文件，连接CPU核和存储器 |
| memory.v              |  存储器，包含指令存储器（即ITCM）和数据存储器（即DTCM） |
| conf_mem.v            |  配置模块，通过报文配置ITCM和DTCM，其中以太网协议字段为0x9001-0x9004，以及输出程序中的"printf"内容，以太网协议字段为0x9005 |
| um_for_cpu.v          |  项目为CPU建立的顶层文件，包含CPU核顶层和配置CPU的模块，即TuMan_top.v和conf_mem.v |
| parser_pkt.v          |  报文解析，解析TCP报文并送给报文处理模块，即manage_pkt.v |
| manage_pkt.v          |  报文处理，将报文缓存进RAM，待CPU处理完报文后，从RAM读取报文，并输出 |
| um_for_pktPipeline.v  |  项目为pipeline建立的顶层文件，包含解析和报文处理模块，即parser_pkt.v和manage_pkt.v |
| um.v                  |  项目的顶层模块，接口定义参见[FAST开源项目](http://www.fastswitch.org/), 负责从网口接收报文，以及向网口发送报文 |
| gen_data_fixed_instr.v|  指令静态存储, 根据FAST报文格式生成以太网报文，用于配置存储器，即ITCM and DTCM。供仿真使用 |
| testbench_for_L2SW.v  |  项目的测试激励，供仿真使用 |

### 连接关系

## 软件部分
There are 2 floders in "Software" folder:

| Folder name | Function description |
|-------------|----------------------|
| firmware    | generate firmware.hex|
| controller  | communicate with cpu |

## Simulation
### Steps
1) Generating firmware.hex by using commonds in firmware folder
2) Using vivado/Modesim to simulate these project by loading hardware files and firmware.hex

### Result
Run this program, and you will get following result: "Hello, AoTuman!"

## FPGA Emulation
We currently only provide support for the [OpenBox-S4](https://github.com/fast-codesign/FAST-OpenBox_S4-impl). We provide pre-build binary program and bitstream files for OpenBox-S4 [here](https://github.com/JunnanLi/TuMan/tree/master/mcs%26hex).  
### Generating binary program
We use commonds in firmware folder to Generate firmware.hex

### Generating bitstream
First, we need a typical [OpenBox-S4 project](https://github.com/fast-codesign/FAST-OpenBox_S4-impl), and replace the `um.v` with our `um.v`.
Then, we add our ohter hardware verilog files, i.e., `TuMan_core.v`, `TuMan_top.v`, `conf_mem.v` and `memory.v`.
Third, we use Vivado 2018.2. to generate bitstream, i.e., OpenBox_S4.bit.

### Communicate with CPU
We use commonds in controller folder to communicate with CPU

### Result
We can recieve values returned from CPU by run t_recv:  
>>interface: enp0s31f6  
>>dtcm_sel is 0  
>>dtcm_sel is 1  
>>  
>>===============  
>>Hello, AoTuman!  
>>\===============  
>>  
>>DONE  
