
#  A simplified CPU memory map
#
#  +-------------+ 0x10000
#  |   PRG-ROM   |
#  |  Upper Bank |
#  |- - - - - - -| 0xC000
#  |   PRG-ROM   |
#  |  Lower Bank |
#  +-------------+ 0x8000
#  |    SRAM     |
#  +-------------+ 0x6000
#  |Expansion ROM|
#  +-------------+ 0x4020
#  |I/O Registers|
#  |- - - - - - -| 0x4000
#  |   Mirrors   |
#  |- - - - - - -| 0x2008
#  |I/O Registers|
#  +-------------+ 0x2000
#  |   Mirrors   |
#  |- - - - - - -| 0x0800
#  |     RAM     |
#  |- - - - - - -| 0X0200
#  |    Stack    |
#  |- - - - - - -| 0x0100
#  | Zero Page   |
#  +-------------+ 0x0000
#
memory = []

def initialize():
    global memory

    memory = [0] * 0x10000
