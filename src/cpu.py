import config
import memory as mem

# Accumulator - 8 bits 
A = 0

# Indexes - 8 bits 
X = 0
Y = 0

# Program Counter - 16 bits
PC = 0

# Stack Pointer - 8 bits
# The stack pointer works top-down, when a byte is pushed it is decremented,
# when a byte is pulled the stack pointer is incremented.
# There is no detection of stack overflow and the stack pointer 
# will just wrap around from $00 to $FF.
S = 0

# Status Register - 8 bits
# 6 bits are used byte the Arithmetic Logic Unit (ALU) 
#
#  C - Carry Flag
#  Z - Zero Flag
#  I - Interrupt Disable
#  D - Decimal Mode
#  B - Break Command
#  V - Overflow Flag
#  N - Negative Flag 
#
# +-+-+-+-+-+-+-+-+
# |N|V| |B|D|I|Z|C|
# +-+-+-+-+-+-+-+-+
#  7 6 5 4 3 2 1 0
P = 0

# The NES opcodes range from 0x00 to 0xFF
opcode = 0

def initialize():
  global A, X, Y, PC, S, P, opcode
    
  A  = 0
  X  = 0
  Y  = 0
  PC = 0xC000
  S  = 0x01FF
  P  = 0
  opcode = 0

def cycle():
  global PC, opcode
  debug()
  opcode = mem.memory[PC]
  decode(opcode)

def decode(opcode):
  global A, X, Y, PC, S, P

  if opcode == 0x18: # CLC - Clear Carry Flag

    # 0 -> C
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - 0
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   implied       CLC           18    1     2
    
    set_carry_flag(0b0)

    PC += 1

  elif opcode == 0x20: # JSR - Jump to New Location Saving Return Address

    # push (PC + 2)
    # (PC + 1) -> PCL
    # (PC + 2) -> PCH
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   absolute      JSR oper      20    3     6
    
    s_push(PC)
    
    PC = (mem.memory[PC + 2] << 8) | mem.memory[PC + 1]

    PC += 3

  elif opcode == 0x38: # SEC - Set Carry Flag
    # 1 -> C
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - 1
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   implied       CLC           18    1     2
    
    set_carry_flag(0xFF)

    PC += 1

  elif opcode == 0x48: # PHA - Push Accumulator on Stack
    # push A
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   implied       PHA          48    1     3

    s_push(A)

    PC += 1

  elif opcode == 0x69: # ADC - Add Memory to Accumulator with Carry
    # A + M + C -> A, C
    #  |N|V| |B|D|I|Z|C|
    #   + + - - - - + +
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   immidiate     ADC #oper     69    2     2

    # Overflow Flag
    set_overflow((A + mem.memory[PC + 1] + (P & 0b1)), A, mem.memory[PC + 1])

    # Carry Flag and operations
    if A + mem.memory[PC + 1] + (P & 0b1) > 0xFF:
      set_carry_flag(0b1)
      A = 0x0
    else:
      A += mem.memory[PC + 1] + (P & 0b1)
      A &= 0xFF # Ensure the 8 bits
      set_carry_flag(0b0)

    # Zero Flag
    set_zero_flag(A)
    
    # Negative Flag
    set_negative_flag(A)

    PC += 2
  
  elif opcode == 0x78: # SEI - Set Interrupt Disable Status
    # 1 -> I                           
    # |N|V| |B|D|I|Z|C|
    #  - - - - - 1 - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # implied       SEI           78    1     2

    set_interrupt_flag(0xFF)

    PC += 1

  elif opcode == 0x81: # STA - Store Accumulator in Memory
    # A -> M
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   (indirect,X)  STA (oper,X)  81    2     6

    loc = mem.memory[PC + 1]
    real_loc = (mem.memory[loc + X + 1] << 8) | mem.memory[loc + X]
    mem.memory[real_loc] = A
    
    PC += 2

  elif opcode == 0x85: # STA - Store Accumulator in Memory
    # A -> M
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   zeropage      STA oper      85    2     3

    mem.memory[PC + 1] = A
    
    PC += 2

  elif opcode == 0x98: # TXA  Transfer Index X to Accumulator
    # X -> A
    #  |N|V| |B|D|I|Z|C|
    #   + + - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   implied       TYA           98    1     2

    A = X

    set_negative_flag(A)
    set_zero_flag(A)
    
    PC += 1

  elif opcode == 0x8D: # STA - Store Accumulator in Memory
    # A -> M
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   absolute      STA oper      8D    3     4


    loc = (mem.memory[PC + 2] << 8) | mem.memory[PC + 1]
    mem.memory[loc] = A
    
    PC += 3

  elif opcode == 0x91: # STA - Store Accumulator in Memory
    # A -> M
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   (indirect),Y  STA (oper),Y  91    2     6

    loc = mem.memory[PC + 1]
    real_loc = (mem.memory[loc + 1] << 8) | mem.memory[loc]
    mem.memory[real_loc + Y] = A
    
    PC += 2

  elif opcode == 0x95: # STA - Store Accumulator in Memory
    # A -> M
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   zeropage,X    STA oper,X    95    2     4

    mem.memory[(PC + 1 + X) & 0xFF] = A
    
    PC += 2

  elif opcode == 0x98: # TYA - Transfer Index Y to Accumulator
    # Y -> A
    #  |N|V| |B|D|I|Z|C|
    #   + + - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   implied       TYA           98    1     2

    A = Y

    set_negative_flag(A)
    set_zero_flag(A)
    
    PC += 1

  elif opcode == 0x99: # STA - Store Accumulator in Memory
    # A -> M
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   absolute,Y    STA oper,Y    99    3     5


    loc = (mem.memory[PC + 2] << 8) | mem.memory[PC + 1]
    mem.memory[loc + Y] = A
    
    PC += 3

  elif opcode == 0x9A: # TXS - Transfer Index X to Stack Register

    # X -> SP
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   implied       TXS           9A    1     2

    S = X
    
    PC += 1

  elif opcode == 0x9D: # STA - Store Accumulator in Memory
    # A -> M
    #  |N|V| |B|D|I|Z|C|
    #   - - - - - - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   absolute,X    STA oper,X    9D    3     5


    loc = (mem.memory[PC + 2] << 8) | mem.memory[PC + 1]
    mem.memory[loc + X] = A
    
    PC += 3

  elif opcode == 0xA1: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # (Indirect, X) LDA           A1    2     6

    loc = (mem.memory[PC + 1] + X) & 0xFF
    real_loc = (mem.memory[loc + 1] << 8) | mem.memory[loc]
    A = mem.memory[real_loc]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 2

  elif opcode == 0xA2: # LDA - Load Accumulator With Memory
    # M -> X                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # Immediate     LDA           A9    2     2
 
    X = mem.memory[PC + 1]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 2

  elif opcode == 0xA5: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # Zero Page     LDA           A5    2     3

    loc = mem.memory[PC + 1]
    A = mem.memory[loc]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 2

  elif opcode == 0xA9: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # immidiate     LDX #oper     A2    2     2
 
    A = mem.memory[PC + 1]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 2

  elif opcode == 0xAD: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # Absolute      LDA           AD    3     4

    loc = (mem.memory[PC + 2] << 8) | mem.memory[PC + 1]
    A = mem.memory[loc]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 3

  elif opcode == 0xB1: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # (Indirect), Y LDA           B1    2     5*
    # * Add 1 if page boundary is crossed

    loc = mem.memory[PC + 1]
    real_loc = (mem.memory[loc + 1] << 8) | mem.memory[loc]
    A = mem.memory[loc + Y]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 2

  elif opcode == 0xB5: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # Zero Page, X  LDA           B5    2     4

    loc = (mem.memory[PC + 1] + X) & 0x00FF
    A = mem.memory[loc]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 2

  elif opcode == 0xB9: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # Absolute, Y   LDA           B9    3     4*
    # * Add 1 if page boundary is crossed

    loc = (mem.memory[PC + 2] << 8) | mem.memory[PC + 1]
    A = mem.memory[loc + Y]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 3

  elif opcode == 0xBD: # LDA - Load Accumulator With Memory
    # M -> A                           
    # |N|V| |B|D|I|Z|C|
    #  + + - - - - - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # Absolute, X   LDA           BD    3     4*
    # * Add 1 if page boundary is crossed

    loc = (mem.memory[PC + 2] << 8) | mem.memory[PC + 1]
    A = mem.memory[loc + X]

    set_zero_flag(A)
    set_negative_flag(A)

    PC += 3
  
  elif opcode == 0xD8: # CLD - Clear Decimal Mode
    # 0 -> D
    #  |N|V| |B|D|I|Z|C|
    #   - - - - 0 - - -
    #
    #   addressing    assembler    opc  bytes  cyles
    #   --------------------------------------------
    #   implied       PHA          D8    1     2

    set_decimal_flag(0b0)

    PC += 1

  else:
    print('The opcode', hex(opcode) , ' is not implemented.')
    exit(-1)

## Status Register Flags
# C
def set_carry_flag(value):
  global P
  P &= 0b1111_1110 # Clears previus C flag
  P |= value & 0b1

# Z
def set_zero_flag(value):
  global P
  P &= 0b1111_1101 # Clears previus Z flag
  if not value: P |= 0b0010

# I
def set_interrupt_flag(value):
  global P
  P &= 0b1111_1011 # Clears previus I flag
  P |= value & 0b0000_0100

# D
def set_decimal_flag(value):
  global P
  P &= 0b1111_0111 # Clears previus I flag
  P |= value & 0b0000_1000 

# B
def set_break_flag(value):
  global P
  P &= 0b1110_1111 # Clears previus B flag
  P |= value & 0b0001_0000

# V
def set_overflow(result, x, y):
  global P
  P &= 0b1011_1111 # Clears previus V flag
  if (x ^ result) & (y ^ result) & 0b1000_0000: P |= 0b1000_0000

# N
def set_negative_flag(value):
  global P
  P &= 0b0111_1111 # Clears previus N flag
  P |= 0b1000_0000 & value

# Stack Pointer
def s_push(value):
  global S
  S = ((S + 0x1) & 0x00FF) | 0x0100
  mem.memory[S] = value

def s_pull():
  global S
  S = ((S - 0x1) & 0x00FF) | 0x0100
  return mem.memory[S]

# Debug
def debug():
  global A, X, Y, PC, S, P, opcode
  
  print('A      :', hex(A))
  print('X      :', hex(X))
  print('Y      :', hex(Y))
  print('PC     :', hex(PC))
  print('opcode :', hex(opcode))
  print('S      :', hex(S))
  print('P      :', bin(P))
  print('------------------')
