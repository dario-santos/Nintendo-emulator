#ifndef _6502_H_
#define _6502_H_

#include <stdint.h>

void cpu_cycle();

void cpu_write(uint16_t address, uint8_t data);

uint8_t cpu_read(uint16_t address);

#endif
