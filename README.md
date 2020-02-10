# iCore项目
iCore可用于in-line FPGA-CPU协同分组处理。iCore整体架构如下图所示，其中CPU采用10级流水的RISCV核，即[TuMan32](https://github.com/JunnanLi/TuMan)，通过访存适配接口，即Memory Access for CPU，可以直接访问基于RAM实现的报文缓存区，从而实现报文的读取与修改。另外，分组处理流水线（pipeline）同样可以通过访存适配接口，即Memory Access for pipeline访问相同的报文缓存区。因此，iCore可以避免上送CPU的报文从流水线拷贝到CPU，以及从CPU拷贝回流水线的多次报文复制。iCore的流水线与CPU交互过程无需报文拷贝（零拷贝），从而降低处理延时，并能通过修改RAM位宽来自定义CPU与FPGA交互的带宽。

<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/iCore%E6%95%B4%E4%BD%93%E6%9E%B6%E6%9E%84.PNG width="600">

此外，我们还设计了单独的RAM，即图中的RAM5，方便CPU主动发送报文，可用于实现TCP/IP协议栈等功能。

## 目录
  * [icore简介](#iCore项目)
  * [icore硬件部分](#icore硬件部分)
     * [硬件模块组成](#硬件模块组成)
     * [硬件模块连接关系](#硬件模块连接关系)
  * [icore软件部分](#icore软件部分)
  * [Vivado仿真](#Vivado仿真)
     * [流程](#流程)
     * [仿真结果](#仿真结果)
  * [FPGA验证](#FPGA验证)
     * [生成CPU可运行的二进制文件](#生成CPU可运行的二进制文件)
     * [生成FPGA可运行的比特流文件](#生成FPGA可运行的比特流文件)
     * [与CPU交互](#与CPU交互)
     * [验证结果](#验证结果)
  * [更多](#更多)
     * [资源开销](#资源开销)
     * [简化版TCP-IP协议栈测试](#简化版TCP-IP协议栈测试)

## icore硬件部分
### 硬件模块组成
硬件文件夹包含11个文件，功能如下表所示

| 文件名                 | 包含的模块    | 功能描述 |
|:---------------------:|:-----------:|---------|
| TuMan_core.v          |  TuMan_core | 10级流水RISCV核（[TuMan](https://github.com/JunnanLi/TuMan)） |
| TuMan_top.v           |  TuMan_top  |CPU核顶层文件，连接CPU核和存储器 |
| memory.v              |  mem_instr<br>mem_data  |指令存储器（即ITCM）<br>数据存储器（即DTCM） |
| conf_mem.v            |  conf_mem   |配置模块，通过报文配置ITCM和DTCM，其中以太网协议字段为0x9001-0x9004，以及输出程序中的"printf"内容，以太网协议字段为0x9005 |
| um_for_cpu.v          |  um_for_cpu |项目为CPU建立的顶层文件，包含CPU核顶层和配置CPU的模块，即TuMan_top.v和conf_mem.v |
| parser_pkt.v          |  parser     |报文解析，解析TCP报文并送给报文处理模块，即manage_pkt.v |
| manage_pkt.v          |  manager    |文处理，将报文缓存进RAM，待CPU处理完报文后，从RAM读取报文，并输出 |
| um_for_pktPipeline.v  |  um_for_pktPipeline|项目为pipeline建立的顶层文件，包含解析和报文处理模块，即parser_pkt.v和manage_pkt.v |
| um.v                  |  um         |项目的顶层模块，接口定义参见[FAST开源项目](http://www.fastswitch.org/), 负责从网口接收报文，以及向网口发送报文 |
| gen_data_fixed_instr.v|  gen_data   |指令静态存储, 根据FAST报文格式生成以太网报文，用于配置存储器，即ITCM and DTCM。供仿真使用 |
| testbench_for_iCore.v |  test_for_icore|项目的测试激励，供仿真使用 |

### 硬件模块连接关系
模块间的连接关系如下图所示。iCore硬件部分（UM.v）可以分成上下两层，上层为um_for_cpu，实现CPU相关功能，包括配置指令和数据、指令与数据存储单元、CPU核运行单元；下层um_for_pipeline，实现硬件流水线功能，包含报文解析、报文处理模块。另外，基于RAM实现的报文缓存单元放在流水线的报文处理模块当中（manage_pkt.v），其具有两个访问端口，一个供CPU使用，另一个分时供流水线输入、输出使用。为避免流水线输入、输出抢占RAM访问接口，iCore还设计了多个独立的RAM，通过分时复用RAM读写端口，可以获得线速访存性能。

<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/%E6%A8%A1%E5%9D%97%E8%BF%9E%E6%8E%A5%E5%85%B3%E7%B3%BB.PNG width="600">

## icore软件部分
软件部分需要实现两部分功能，分别是编译C程序生成CPU可以运行的二进制文件，以及实现外部主机和CPU交互的功能。为此，iCore软件的两个功能在项目中对应两个文件夹，即firmware和controller。具体功能如下表所述：

| 文件夹名     | 功能描述 |
|:-----------:|----------------------|
| firmware    | 负责编译C代码生成二进制文件firmware.hex|
| controller  | 负责将二进制文件写入CPU的存储器中，同时实现打印CPU运行过称中的打印信息 |

软件部分在终端主机上运行，与FPGA的交互通过以太网报文实现（实现机制参考[FAST项目](https://github.com/Winters123/paper-base/blob/master/FAST-final.pdf)）。iCore软件部分与FPGA的交互过程如下图所示。

<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/%E5%A4%84%E7%90%86%E6%B5%81%E7%A8%8B.PNG width="700">


## Vivado仿真
### 流程
1) 根据firmware文件夹的[README](https://github.com/JunnanLi/iCore/blob/master/software/Firmware/README.md)编译C程序，以生成firmware.hex二进制文件。当然我们也提供预先编译好的[firmware.hex]；(https://github.com/JunnanLi/iCore/blob/master/mcs%26hex/firmware.hex)，实现了端口环路的功能，即报文1扣进，1口出；
2) 打开vivado，加载[hardware](https://github.com/JunnanLi/iCore/tree/master/hardware)文件夹中的所有.v/.sv文件(gen_data_instr.sv除外)，并将test_for_icore设置为顶层文件；
3) 读取firmware.hex的指令，并更新[gen_data_fixed_instr.sv](https://github.com/JunnanLi/iCore/blob/master/hardware/gen_data_fixed_instr.sv)中的memory寄存器（27行）。目前我们实现的方式是运行[write_instr.py](https://github.com/JunnanLi/iCore/blob/master/hardware/write_instr.py)，需要保证firmware.hex，[gen_data_instr.sv](https://github.com/JunnanLi/iCore/blob/master/hardware/gen_data_instr.sv)在相同目录。当然我们也提供预先编译好的[gen_data_fixed_instr.sv](https://github.com/JunnanLi/iCore/blob/master/hardware/gen_data_fixed_instr.sv)；
4） 运行程序

### 仿真结果
加载um模块的pktout_data_wr和pktout_data两组接口信号，我们可以发现，在运行12.86us之后会输出5个TCP报文。


## FPGA验证
我们目前仅支持在[OpenBox-S4](https://github.com/fast-codesign/FAST-OpenBox_S4-impl)上验证iCore项目。我们提供预先编译好的[二进制文件](https://github.com/JunnanLi/iCore/tree/master/mcs%26hex)，可以直接用于FPGA验证。

### 生成CPU可运行的二进制文件
我们使用firmware文件夹中的[README](https://github.com/JunnanLi/iCore/blob/master/software/Firmware/README.md)生成firmware.hex二进制文件。

### 生成FPGA可运行的比特流文件
1) 首先，我们需要一个OpenBox-S4平台相关代码，点击[这里](https://github.com/fast-codesign/FAST-OpenBox_S4-impl)获取，并使用该项目中的`um.v`替换原来的`um.v`；
2) 接着，我们使用Vivado 2018.2打开Openbox工程，并加载其他的八个硬件模块文件，即`TuMan_core.v`, `TuMan_top.v`, `conf_mem.v`, `memory.v`, `um_for_cpu.v`, `um_for_pipeline.v`, `parser_pkt.v`, `manage_pkt.v`;
3) 第三，我们为该项目生成五个IP核，分别是fifo_134_256（同步fifo），fifo_8_64（同步fifo），fifo_96_64（同步fifo），ram_32_512（双端口RAM），ram_32_16384（双端口RAM）；
4）运行`Generate Bitstream`，生成FPGA可运行的比特流文件，即OpenBox_S4.bit；

### 与CPU交互
我们根据controller文件夹中[README](https://github.com/JunnanLi/iCore/blob/master/software/Controller/README.md)实现与CPU的交互。

### 验证结果
1) 首先，代开`Hardware Manager`，并将比特流文件烧入FPGA中；
2) 使用根据controller文件夹中[README](https://github.com/JunnanLi/iCore/blob/master/software/Controller/README.md)配置CPU指令、数据内容，并开启运行；
3) 打开wiresharek，使用发包工具发送任意的TCP报文，可以抓到FPGA返回的相同TCP报文。

## 更多

### 资源开销
| Module             | Slice LUTs | Slice Registers | Block Memory Tile |
|:------------------ | ----------:| ---------------:| -----------------:|
| parser_pkt         |         52 |             540 |                 0 |
| manage_pkt         |        322 |             501 |                 7 |
| conf_mem           |        283 |             500 |                 2 |
| memory             |        162 |              49 |              30.5 |
| TuMan_core         |       6294 |            3086 |                 0 |


### 简化版TCP-IP协议栈测试
1) ICMP测试
我们将iCore的IP地址设置为202.197.15.129，然后笔记本端输入`ping 202.197.15.129`命令
<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/ping.png width="400">

2) UDP测试
我们将iCore的IP地址设置为202.197.15.129，并作为UDP客户端，然后笔记本作为UDP服务端，实现UDP交互
<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/udp.png width="400">

3) TCP测试
我们将iCore的IP地址设置为202.197.15.129，并作为TCP客户端，然后笔记本作为TCP服务端，实现TCP交互
<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/tcp.png width="400">




