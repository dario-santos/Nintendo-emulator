import loader
import memory as mem
import cpu
import ppu
import pygame

def initialize():
  display_buffer = [0] * 256 * 240

  screen = pygame.display.set_mode((256, 240))
  pygame.display.flip()
  pygame.display.update()

  pygame.display.set_caption('Nintendo')

def start_emulator():
  pygame.init()

  initialize()


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
    ppu.cycle()

  


start_emulator()
