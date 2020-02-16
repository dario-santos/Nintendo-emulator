CC=gcc
FLAGS= -c -Wall
LIBS=
OBS=6502.o bus.o emulator.o
BIN=emulator

all : $(BIN)

emulator.o : 
	$(CC) $(FLAGS) emulator.c

6502.o : 6502.h 6502.c
	$(CC) $(FLAGS) 6502.c

bus.o : bus.h 6502.h bus.c
	$(CC) $(FLAGS) bus.c

$(BIN) : $(OBS)
	$(CC)  -o $(BIN)  $(OBS) $(LIBS)

clean limpar:
	rm -f *.o $(BIN)
	echo "Limpeza dos ficheiros exectuaveis, objectos e gedit tralha"
