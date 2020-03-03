all:
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o GenHex/system.o Source/system.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o GenHex/list.o Source/list.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o GenHex/task.o Source/tasks.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o GenHex/port.o Source/port.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o GenHex/queue.o Source/queue.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o GenHex/string.o Source/string.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o GenHex/mainFreeRTOS.o Source/mainFreeRTOS.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -o GenHex/start.o Source/start.S
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -Os -ffreestanding -nostdlib -o GenHex/firmware.elf         -Wl,-Bstatic,-T,GenHex/sections.lds,-Map,GenHex/firmware.map,--strip-debug         GenHex/start.o GenHex/system.o GenHex/string.o GenHex/mainFreeRTOS.o GenHex/list.o GenHex/task.o GenHex/port.o GenHex/queue.o -lgcc
	chmod -x GenHex/firmware.elf
	/opt/riscv32i/bin/riscv32-unknown-elf-objcopy -O binary GenHex/firmware.elf GenHex/firmware.bin
	python3 GenHex/makehex.py GenHex/firmware.bin 16384 > GenHex/firmware.hex

clean:
	rm GenHex/start.o GenHex/mainFreeRTOS.o GenHex/system.o GenHex/string.o GenHex/list.o GenHex/task.o GenHex/port.o GenHex/queue.o GenHex/firmware.elf GenHex/firmware.bin GenHex/firmware.hex GenHex/firmware.map
