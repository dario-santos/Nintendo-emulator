
# The list is in the orther that the NES reads the status of the controller

input_schema = [
  'N': 0, # A
  'M': 0, # B
  'H': 0, # Select
  'J': 0, # Start
  'W': 0, # Up
  'S': 0, # Down
  'A': 0, # Left
  'D': 0  # Right
]

def initialize()
  global input_schema

  for k in input_schema.keys():
    input_schema[k] = 0
