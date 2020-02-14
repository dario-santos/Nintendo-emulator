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
  PC = config.prg_start
  S  = 0x01FF
  P  = 0
  opcode = 0

def cycle():
  global PC, opcode
  debug()
  opcode = mem.memory[PC]
  decode(mem.memory[PC])

def decode(opcode):
  global A, X, Y, PC, S, P

  if opcode == 0x69: # ADC - Add Memory to Accumulator with Carry
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
      clear_carry_flag(0b0)

    # Zero Flag
    update_zero_flag(A)
    
    # Negative Flag
    update_negative_flag(value)

    PC += 2
  
  elif opcode == 0x78: # SEI - Set Interrupt Disable Status
    # 1 -> I                           
    # |N|V| |B|D|I|Z|C|
    #  - - - - - 1 - -
    #
    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # implied       SEI           78    1     2

    P |= 0b00000100
    PC += 1
  else:
    print('The opcode', hex(PC) , ' is not implemented.')
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
def set_break(value):
  global P
  P &= 0b1111_1011 # Clears previus I flag
  P |= value & 0b0000_0100

# B
def set_break(value):
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
