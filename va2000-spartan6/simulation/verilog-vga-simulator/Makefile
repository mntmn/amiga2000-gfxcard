
LDFLAGS=$(shell sdl-config --libs)
CCFLAGS=$(shell sdl-config --cflags)

all: vgasim.vpi

demo: demo.vvp vgasim.vpi
	@echo ----------------------------------------------
	vvp -M. -mvgasim demo.vvp

%.vpi: %.c
	iverilog-vpi $< -I/usr/include/SDL -lSDL

%.vvp: %.v
	iverilog $< -o $@
