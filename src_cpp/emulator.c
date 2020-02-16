#include <stdio.h>
#include "bus.h"

int main()
{
	printf("HI!\n");
	
	if(bus_initialize()) 
		printf("RAM INITIALIZED\n");

	printf("Value: %d\n", bus_read(0xA));

	return 0;
}
