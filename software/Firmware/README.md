# Firmware
We provide basic files to generate an example binary program by following commonds:
1) `$path_to_riscv/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o firmware/print.o firmware/print.c`
2) `$path_to_riscv/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic  -ffreestanding -nostdlib -o firmware/tuman_program.o firmware/tuman_program.c`
3) `$path_to_riscv/bin/riscv32-unknown-elf-gcc -c -mabi=ilp32 -march=rv32i -o firmware/start.o firmware/start.S`
4) `$path_to_riscv/bin/riscv32-unknown-elf-gcc -Os -ffreestanding -nostdlib -o firmware/firmware.elf         -Wl,-Bstatic,-T,firmware/sections.lds,-Map,firmware/firmware.map,--strip-debug         firmware/start.o firmware/tuman_program.o firmware/print.o -lgcc`
5) `chmod -x firmware/firmware.elf`
6) `$path_to_riscv/bin/riscv32-unknown-elf-objcopy -O binary firmware/firmware.elf firmware/firmware.bin`
7) `chmod -x firmware/firmware.bin`
8) `python3 firmware/makehex.py firmware/firmware.bin 16384 > firmware/firmware.hex`

## Note
1) You should export the `path_to_riscv` first, e.g., `export path_to_riscv=/opt/riscv32i` in our environment
2) You can replace tuman_program.c with your own program
