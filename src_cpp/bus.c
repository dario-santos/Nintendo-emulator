#include "bus.h"
#include <stdlib.h>

// Memória RAM
uint8_t * ram = NULL;

// CPU 6502

int bus_initialize()
{
    ram = (uint8_t*) calloc(sizeof(uint8_t), 0x0800);

    for(int i = 0 ; i < 0x0800 ; i++)
        ram[i] = i;

    return 1;
}

void bus_write(uint16_t address, uint8_t data)
{
}

uint8_t bus_read(uint16_t address)
{
    return address <= 0xFFFF && address >= 0x0000 ? ram[address % 0x0800] : 0;
}
