#include "6502.h"

int PC = 0x0000;
int A  = 0x00;
int X  = 0x00;
int Y  = 0x00;
int S  = 0x00;
int P  = 0x00;

int clock = 0;

void cpu_write(uint16_t address, uint8_t data)
{

}

uint8_t cpu_read(uint16_t address)
{
    return 0;
}

void cpu_cycle()
{
    if(clock == 0) 
        // Execute opcode
        ;
        
    --clock;
}
