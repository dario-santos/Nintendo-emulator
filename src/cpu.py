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
  S  = 0xFF
  P  = 0
  opcode = 0

def cycle():
  global PC, opcode
  debug()
  opcode = mem.memory[PC]
  decode(mem.memory[PC])

def decode(opcode):
  global A, X, Y, PC, S, P

 if opcode == 0x78: # SEI - Set Interrupt Disable Status
    # 1 -> I                           
    # |N|V| |B|D|I|Z|C|
    #  - - - - - 1 - -

    # addressing    assembler    opc  bytes  cyles
    # --------------------------------------------
    # implied       SEI           78    1     2

    P |= 0b00000100
    PC += 1
  else:
    print('The opcode', hex(PC) , ' is not implemented.')
    exit(-1)

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