
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

def initialize():
  global A, X, Y, PC, S, P
    
  A  = 0
  X  = 0
  Y  = 0
  PC = 0
  S  = 0
  P  = 0

