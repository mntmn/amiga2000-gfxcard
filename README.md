# Amiga 2000 Graphics Card (Zorro II)

This repository contains my Kicad schematics and Xilinx ISE/Verilog files for my graphics card project. This is a work in progress, started in October 2015. The first 4 prototypes were assembled in Jan/Feb 2016 and had noise problems, so I started a redesign on Feb 13, 2016.

## Attempt 2

On Mar 27th, 2016, the redesign worked and I could load a 16 bit 565BGR coded raw image from floppy into the graphics card that displayed a 1280x720p resolution (75mhz pixelclock).

The working Xilinx project for the new target platform (Scarab miniSpartan 6+) is now in the z2-minispartan folder.

Contains a modified SDRAM controller (Verilog) and a DVI encoder (VHDL) by Mike Field.
