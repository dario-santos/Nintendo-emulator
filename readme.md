# Nintendo Emulator

## 1. CPU

### 1.1 CPU Memory Map

The following diagram illustrates the CPU memory map

    +-------------+ 0x10000
    |   PRG-ROM   |
    |  Upper Bank |
    |- - - - - - -| 0xC000
    |   PRG-ROM   |
    |  Lower Bank |
    +-------------+ 0x8000
    |    SRAM     |
    +-------------+ 0x6000
    |Expansion ROM|
    +-------------+ 0x4020
    |I/O Registers|
    |- - - - - - -| 0x4000
    |   Mirrors   |
    |- - - - - - -| 0x2008
    |I/O Registers|
    +-------------+ 0x2000
    |   Mirrors   |
    |- - - - - - -| 0x0800
    |     RAM     |
    |- - - - - - -| 0X0200
    |    Stack    |
    |- - - - - - -| 0x0100
    | Zero Page   |
    +-------------+ 0x0000

### 1.2 CPU Registers

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

## 1.2.1 Accumulator - A

The accumulator is an 8-bit register that stores the results of arithmetic and logic operations.

## 1.2.2 Index Registers - X, Y

The X and Y registers are both 8-bit.

## 1.2.3 Program Counter - PC

The program counter is a 16-bit register wich holds the address of the **next** instruction to be executed.

## 1.2.4 Stack Pointer - S

The stack is located between the memory locations 0x0100 to 0x01FF ( This can be visualized in the diagram CPU Memory Map).

The stack pointer is an 8-bit register, the stack works top-down wich means that when a byte is pushed the stack pointer is incremented. There is no overflow, the stack pointer will wrap around from 0x0100 to 0x01FF.

The stack pointer allways points to the next free location.

## 1.2.5 Status Register - P

Six of the eigth bits of the status register (**P**) are used by the arithmetic logic unit (**ALU**).

The 8-bits of the status register follow structure:

    +-+-+-+-+-+-+-+-+ 
    |N|V| |B|D|I|Z|C|
    +-+-+-+-+-+-+-+-+
     7 6 5 4 3 2 1 0

Description:

C - Carry Flag        <br>
Z - Zero Flag         <br>
I - Interrupt Disable <br>
D - Decimal Mode      <br>
B - Break Command     <br>
V - Overflow Flag     <br>
N - Negative Flag 

## Addressing Modes of the 6502

### Zero Page

Zero page addressing uses a single operand wich serves as a pointer to an address in zero page (0x0000 to 0x00FF).

Example:

    Instruction: AND 0x12

    A &= RAM[PC + 1];
    ...
    PC += 2;

    |        |
    +--------+
    |  AND   | PC     <-- Current Opcode 
    +--------+
    | 0x0012 | PC + 1 <-- The memory location of the value
    +--------+
    | ...... | PC + 2 <-- The next Opcode
    +--------+
    |        |


### Indexed Zero Page

Indexed zero page addressing takes a single operand and adds the value of a register to calculate the zero page address.

There are two forms of indexed zero page addressing:

- Zero Page, X - Add contents of X register to operand.

- Zero Page, Y - Add contents of Y register to operand.

The wrap technique is used to assure that the sum will not exceed the zero page addresses. In other words, 0x0001 + 0x00FF = 0x0000 instead of 0x0100.

Example:

    Instruction: AND 0x12, X


    A &= RAM[PC + 1 + X];
    ...
    PC += 2;

    |        |
    +--------+
    |  AND   | PC     <-- Current Opcode 
    +--------+
    | 0x0012 | PC + 1 <-- The memory location of the value
    +--------+
    | ...... | PC + 2 <-- The next Opcode
    +--------+
    |        |

### Absolute

In absolute addressing, the address of the data to operate on is specified by the two operands supplied, least significant byte first.


Example:

    Instruction: AND 0x1234

    address = (RAM[PC + 2] << 8) | RAM[PC + 1];
    A &= RAM[address];
    ...
    PC += 3;

    |        |
    +--------+
    |  AND   | PC     <-- Current Opcode 
    +--------+
    | 0x0034 | PC + 1 <-- The least significant byte
    +--------+
    | 0x0012 | PC + 2 <-- The most significant byte
    +--------+
    | ...... | PC + 3 <-- The next Opcode
    +--------+
    |        |

### Indexed Absolute

Indexed absolute addressing takes two operads, forming a 16-bit address (just like absolute addressing). The difference is that we sum the value of a register to calculate the final address.

There are two forms of indexed absolute addressing

- Absolute, X - Add contents of X register to operand.

- Absolute, Y - Add contents of Y register to operand.


Example:

    Instruction: AND 0x1234, X


    address = (RAM[PC + 2] << 8) | RAM[PC + 1];
    A &= RAM[address + X];
    ...
    PC += 3;

    |        |
    +--------+
    |  AND   | PC     <-- Current Opcode 
    +--------+
    | 0x0034 | PC + 1 <-- The least significant byte
    +--------+
    | 0x0012 | PC + 2 <-- The most significant byte
    +--------+
    | ...... | PC + 3 <-- The next Opcode
    +--------+
    |        |


### Indirect

Indirect addressing takes two operads, forming a 16-bit address (just like absolute addressing). This address is then used to calculate the real value.

Example:

    Instruction: JMP ($1234)


    address = (RAM[PC + 2] << 8) | RAM[PC + 1];

    real_value = (RAM[address + 1] << 8) | RAM[address];

    JMP RAM[real_value]
    
    PC += 3;

    |        |
    +--------+
    |  AND   | PC     <-- Current Opcode 
    +--------+
    | 0x0034 | PC + 1 <-- The least significant byte
    +--------+
    | 0x0012 | PC + 2 <-- The most significant byte
    +--------+
    | ...... | PC + 3 <-- The next Opcode
    +--------+
    |        |
    +--------+
    |  0x56  | 0X1234 <-- Least significant byte of the real value
    +--------+
    |  0x78  | 0x1235 <-- Most significant byte of the real value
    +--------+
    |        |

## Roms

There are a few type of formats, iNES, NES2 and others.

## Memory Map

0000-07FF is RAM, 
0800-1FFF are mirrors of RAM (you AND the address with 07FF to get the effective address)
2000-2007 is how the CPU writes to the PPU
2008-3FFF are mirrors of that address range.
4000-401F is for IO ports and sound
4020-4FFF is rarely used, but can be used by some cartridges
5000-5FFF is rarely used, but can be used by some cartridges, often as bank switching registers, not actual memory, but some cartridges put RAM there
6000-7FFF is often cartridge WRAM. Since emulators usually emulate this whether it actually exists in the cartridge or not, there's a little bit of controversy about NES headers not adequately representing a cartridge.
8000-FFFF is the main area the cartridge ROM is mapped to in memory. Sometimes it can be bank switched, usually in 32k, 16k, or 8k sized banks.

The NES header takes up 16 bytes, after that is the PRG pages, then after that is the CHR pages. You look at the header to see how big the PRG and CHR of the cartridge are, see documentation for more details. The NES header does not exist outside of .NES files, you won't find it on any NES cartridges.

So you load a Mapper 0 (NROM) cartridge into memory, and the first two PRG banks appear in NES memory at 8000-FFFF. If there is only one 16k bank, then it is mirrored at 8000-BFFF and C000-FFFF.

When the CPU boots up, it reads the Reset vector, located at FFFC. That contains a 16-bit value which tells the CPU where to jump to.
The first thing a game will do when it starts up is repeatedly read PPU register 2002 to wait for the NES to warm up, so you won't see a game doing anything until you throw in some rudimentary PPU emulation.
Then the game clears the RAM, and waits for the NES to warm up some more. Then the system is ready, and the game will start running.

## References

- https://wiki.nesdev.com/w/index.php/
- http://www.thealmightyguru.com/Games/Hacking/Wiki/index.php/6502_Opcodes
- http://www.6502.org/tutorials/6502opcodes.html
- https://www.masswerk.at/6502/6502_instruction_set.html
