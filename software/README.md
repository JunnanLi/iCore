# Software
软件部分包含三个文件夹，即firmware,controller和FreeRTOS_on_Tuman32。具体功能如下表所述，详细功能参见各自文件夹中的README：

| Folder name | Function description |
|-------------|----------------------|
| firmware    | 负责编译C代码生成二进制文件firmware.hex|
| controller  | 负责将二进制文件写入CPU的存储器中，同时实现打印CPU运行过称中的打印信息 |
| FreeRTOS_on_Tuman32  | 是另一个功能的firmware,负责实现FreeRTOS的功能 |
