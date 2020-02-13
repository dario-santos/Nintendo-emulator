# Nintendo Emulator

## CPU

### CPU Registers

Unlike many CPUs that have a group of registers, like CHIP8 that has 16 registers, the NES cpu does not have them, instead it has:

 - One accumulator (A)
 - Two indexes (X and Y)
 - One program counter (PC)
 - One stack pointer (S)
 - One status register (P)

| Definition | Size (bits)|
|------------|:----------:|
| A          | 8          |
| X          | 8          |
| Y          | 8          |
| PC         | 16         |
| S          | 8          |
| P          | 8          |

Six of the eigth bits of the status register (**P**) are used by the arithmetic logic unit (**ALU**).
 