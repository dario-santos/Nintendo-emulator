
# Todo

## RAM

- [ ] Emulate Memory

## Cartridge

- [X] Detect the rom format
- [ ] Load the rom into memory

## CPU

- [ ] Emulate Opcodes
- [X] Status Register Functions
- [X] Stack Pointer Functions

## PPU

- [ ] Emulate graphics

## Input Devices

- [ ] Emulate a controller


## Opcode List

Down here to not get in the way of the other lists (this is a big one)

### And

- [X] AND

### Clear Flags

- [X] CLC
- [X] CLD
- [X] CLI
- [X] CLV

### Compare Memory With

- [X] CMP
- [X] CPX
- [X] CPY

### Exclusive OR

- [X] EOR

### Increment by One

- [X] INC
- [X] INX
- [X] INY

### Jump To

- [X] JMP
- [X] JSR

### Load With Memory

- [X] LDA
- [X] LDX
- [X] LDY

### Shift One Bit Right

- [X] LSR

### No Operation

- [X] NOP

### OR Memory with Accumulator

- [X] ORA

### Pull/Push from Stack

- [X] PHA
- [X] PHP
- [X] PLA
- [X] PLP

### Rotate One Bit Right/Left

- [X] ROL
- [X] ROR

### Return From

- [X] RTI
- [X] RTS

### Subtract Memory From Accumulator With Borrow

- [X] Immediate
- [X] Zero Page
- [X] Zero Page, X
- [X] Absolute
- [X] Absolute, X
- [X] Absolute, Y
- [X] (Indirect, X)
- [X] (Indirect), Y

### Set Flags 

- [X] SEC
- [X] SED
- [X] SEI

### Store In Memory

- [X] STA (zeropage; zeropage, X; absolute; absolute, X; absolute, Y; (indirect, X); (indirect), Y
- [X] STX (zeropage; zeropage, Y; absolute)
- [X] STY (zeropage; zeropage, X; absolute)

### Tranfers

- [X] TYA
- [X] TXS
- [X] TXA
- [X] TSX
- [X] TAY
- [X] TAX
