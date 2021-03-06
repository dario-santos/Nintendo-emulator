import os
import memory as mem
import config

# ROM iNES - Super Mario (E)
#
# Header
# 0-3: 0x4e 0x45 0x53 0x1A - "NES" followerd by MS-DOS end of file
# 4  : 0x2                 - Size of the PRG ROM in 16KB units (32768 KB)
# 5  : 0x1                 - Size of the CHR ROM in 8KB units (8192 KB)
# 6  : 0x1                 - FLAGS - 1 means vertical mirroring
# 7  : 0x0                 - FLAGS
# 8  : 0x0                 - PRG-RAM size
# 9  : 0x0                 - TV system
# 10 : 0x0                 - TV system, PRG-RAM presence
# 11-15 : 0x0              - Unused padding

# Rom type
# 0 -> NES 2.0
# 1 -> iNES
# 2 -> Archaic iNES
rom_type = 0

def load_file(rom):  
  
  # Open ROM file
  with open(rom, 'rb') as rom:
    rom_length = os.fstat(rom.fileno()).st_size

    # Read Header
    header = []
    for i in range(0x10):
      header.append(int.from_bytes(rom.read(1), "big"))
            
    # Identifies the ROM format
    if(is_nes2(header)):
      rom_type = 0
    if(is_ines(header)):
      rom_type = 1
    else:
      rom_type = 2

    # if trainer_is_present: skip 0x200 bytes
    config.prg_start = 0x210 if header[0x6] & 0b00000100 else 0x010
 
    # Load trainer
    for i in range(0x10, config.prg_start):
      mem.memory[i] = int.from_bytes(rom.read(1), "big")
    
    # Load PRG - Program 
    # 0x8000 -> Lower Bank
    for i in range(0x4000):
      mem.memory[0xC000 + i] = int.from_bytes(rom.read(1), "big")

def is_ines(header):
  if header[0x7] & 0x0C == 0x00:
    for i in range(12, 16):
      if header[i] != 0:
        return False
  return True

def is_nes2(header):
  return True if header[0x7] & 0x0C == 0x08 and header[0x9] < len(header) else False
