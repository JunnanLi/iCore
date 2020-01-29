# iCore项目
iCore可用于in-line FPGA-CPU协同分组处理。iCore整体架构如下图所示，其中CPU采用10级流水的RISCV核，即[TuMan32](https://github.com/JunnanLi/TuMan)，通过访存适配接口，即Memory Access for CPU，可以直接访问pipeline中的RAM（缓存有报文），从而实现报文的读取与修改。另外，pipeline也可以通过相应的访存适配接口，即Memory Access for pipeline访问pipeline中的RAM。因此，iCore最大的特点是pipeline可以直接将报文写入RAM，并由CPU直接读写（零拷贝），而无需重新复制。

<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/iCore%E6%95%B4%E4%BD%93%E6%9E%B6%E6%9E%84.PNG width="600">

## 目录
  * [icore硬件部分](#icore硬件部分)
     * [硬件模块组成](#硬件模块组成)
     * [硬件模块连接关系](#硬件模块连接关系)
  * [icore软件部分](#icore软件部分)
     * [流程](#流程)
     * [仿真结果](#仿真结果)
  * [Vivado仿真](#Vivado仿真)
  * [FPGA验证](#FPGA验证)
     * [生成CPU可运行的二进制文件](#生成CPU可运行的二进制文件)
     * [生成FPGA可运行的比特流文件](#生成FPGA可运行的比特流文件)
     * [与CPU交互](#与CPU交互)
     * [验证结果](#验证结果)

## icore硬件部分
### 硬件模块组成
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
| testbench_for_iCore.v |  项目的测试激励，供仿真使用 |

### 硬件模块连接关系
模块间的连接关系如下图所示。

<img src=https://github.com/JunnanLi/iCore/blob/master/docs/img/%E6%A8%A1%E5%9D%97%E8%BF%9E%E6%8E%A5%E5%85%B3%E7%B3%BB.PNG width="600">

## icore软件部分
软件部分包含两个文件夹，即firmware和controller。具体功能如下表所述，详细功能参见各自文件夹中的README：

| Folder name | Function description |
|-------------|----------------------|
| firmware    | 负责编译C代码生成二进制文件firmware.hex|
| controller  | 负责将二进制文件写入CPU的存储器中，同时实现打印CPU运行过称中的打印信息 |

## Vivado仿真
### 流程
1) 使用firmware文件夹README中的命令生成firmware.hex二进制文件；
2) 打开vivado，加载hardware文件架中.v/.sv文件，其中需要将firmware.hex的指令更新gen_data_fixed_instr.sv。

### 仿真结果
运行上述代码，观察um模块的pktout_data_wr和pktout_data信号，可以发现输出5个TCP报文（在12.86us处），如下图所示。


## FPGA验证
我们目前仅支持在[OpenBox-S4](https://github.com/fast-codesign/FAST-OpenBox_S4-impl)上验证iCore项目。我们提供预先编译好的[二进制文件](https://github.com/JunnanLi/iCore/tree/master/mcs%26hex)，可以直接用于FPGA验证.  

### 生成CPU可运行的二进制文件
我们使用firmware文件夹中README的命令生成firmware.hex二进制文件

### 生成FPGA可运行的比特流文件
1) 首先，我们需要一个[OpenBox-S4平台相关代码](https://github.com/fast-codesign/FAST-OpenBox_S4-impl)，并使用该项目的中的`um.v`替换原来的`um.v`；
2) 接着，加载其他的硬件模块文件，即`TuMan_core.v`, `TuMan_top.v`, `conf_mem.v`, `memory.v`, `um_for_cpu.v`, `um_for_pipeline.v`, `parser_pkt.v`, `manage_pkt.v`;
3) 最后，我们使用Vivado 2018.2生成FPGA可运行的比特流文件，即OpenBox_S4.bit。

### 与CPU交互
我们使用controller文件夹README中的命令实现与CPU的交互。

### 验证结果
打开wiresharek，使用发包工具发送任意的TCP报文，可以抓到FPGA返回的相同TCP报文。
