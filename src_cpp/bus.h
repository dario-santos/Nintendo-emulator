#ifndef _BUS_H_
#define _BUS_H_

#include <stdint.h>
#include "6502.h"

int bus_initialize();

void bus_write(uint16_t address, uint8_t data);

uint8_t bus_read(uint16_t address);

#endif