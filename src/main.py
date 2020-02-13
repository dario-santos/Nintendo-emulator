import loader
import memory as mem
import cpu

def start_emulator():

  # Start memory  
  mem.initialize()

  # Load rom
  loader.load_file('SuperMarioBros(E).nes')

  # Start CPU
  cpu.initialize()

  # Debug functions
  
  # Emulation Loop
  while True:
    cpu.cycle()


start_emulator()
