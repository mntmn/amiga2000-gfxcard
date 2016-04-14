How I decided to make a graphics card for my Amiga 2000

Somewhere in the middle of 2015 I revived my old A500 and acquired again an A1200, the computer I learned C++ and the basics of web programming on in the late 90s. I also played lots of fantastic Amiga games back in the day, made my first music in ProTracker and my first digital graphics in Deluxe Paint. Re-experiencing the old system that was so ahead of its time again made me curious about Commodore's history and especially about the late, big and ambitious Amiga models (A3000, A4000). This coincided with Amiga's 30th anniversary. A lot of new interviews with the original team(s) popped up, including Dave Haynie, who designed most of the A2000 and the Zorro Bus.

I checked eBay for the "big" Amigas I never had, expecting them to be cheap, but found out that these boxes turned into valuable collector's items. At the same time, A2000s were (and still are) affordable, so I chose to get one and put a 68040 and a SCSI card in it. But the system couldn't realize it's full potential; in the 90s you could already get, for example, a "Picasso" graphics card that could do VGA (and higher) resolutions at 16 or 24bit color depth. Nowadays, these totally outdated cards are rare and sold for ridiculous prices.

Because of my work with Microcontrollers, writing a low-level OS for Raspberry Pi and studying computer architectures in general, in October 2015 I decided in a feat of madness: "I'll just make my own graphics card. How hard can it be?"

It turned out to be a very, very challenging project, but luckily I came much further than I expected. On the way, I had to learn how to design a PCB and get it manufactured, how to work with SMD parts, how to program in Verilog and synthesize code for an FPGA, how SDRAM and DVI/HDMI work (or how to get them to do something). I also had to find out how to write a driver for the sadly closed/undocumented Picasso96 "retargetable" graphics stack for AmigaOS 3.

The Amiga is probably the last 32-bit personal computer that is fully understood, documented and hackable. Both its hardware and software contain many gems of engineering and design. I hope that one day, we can have a simple but powerful modern computer that is at the same time as hackable and friendly as the Amiga was.

1. The "engine": FPGA and SDRAM

As a platform for my first attempt (ultimately a failure) I chose the Papilio Pro dev board, which has a Xilinx Spartan 6 FPGA and a few megabytes of  SDRAM connected to it. It also has two pin headers that break out some of the general purpose input/output pins of the Spartan. I thought, OK; I could use the RAM to store the image (a framebuffer), and run a loop that goes through all the columns and rows of the picture in the correct speed and just output the bytes from the RAM to R,G and B output lines. I did this before with little Atmel microcontrollers – "bit-banging" a VGA image directly from the CPU – so I knew it was possible. I just didn't know that SDRAM (synchronous dynamic RAM) was a lot more complex to use than the integrated SRAM (static RAM) of common microcontrollers.

[diagram and explanation of SDRAM timing]

I connected an Arduino to the Papilio and used it to send a few address bits and an "on/off" bit to toggle pixels in the framebuffer on and off. This contraption was able to draw basic fonts on my VGA display, and they were successfully kept in the SDRAM. 

The next step was connecting the FPGA+display part to the Amiga 2000.

2. Zorro II: Reads and Writes

The original Amiga Hardware Manuals helped me understand the Zorro II bus. It is basically an extension (arbitrated by a bus controller chip) of the pins of the Motorola 68000 CPU. The 68k is extensively studied and documented. I understood that I needed a mechanism that would allow the 68k CPU to write data (pixels) to the graphics card's RAM and another for reading back parts of the screen (for scrolling and moving around things).

So I fired up the open source circuit design tool KiCad and started some schematics. The first task was to define the Zorro port as a component with a whopping 100 pins. Of course I made a lot of little mistakes at first and I had no idea why one would need so many different signals. It turned out that I only needed a subset of the pins to get my job done:

2.1. Address Bus (A1-A23)
2.2. Data Bus (D0-D15)
2.3. Upper and Lower "Data Strobes" (UDS / LDS)
2.4. READ, /AS, DOE, signals which the Amiga uses to communicate if it wants to read or write, if it presents a valid address and if it expects a device to send data.
2.5. Power (5V, GND)
2.6. Autoconf (/CFGIN, /CFGOUT)

I figured that I needed to connect most of these signals to the FPGA and then write another loop that would interpret the Amiga's bus commands and act on them (store the data given on the bus in the RAM or return stuff from the RAM). 

On the other side of the FPGA, I decided to place an Analog Devices DAC(XYZ) digital to analog converter chip that would generate the analog R, G and B channels for the VGA port from the bits coming from the framebuffer.

The next hurdle appeared: The Spartan communicate with modern 3.3V logic levels, but the Amiga used legacy 5V signals. So I needed to put voltage translators (also called level shifters) between the Zorro and the FPGA pins. I decided to split the signals into bundles of 8 and use six 8-bit "auto-direction-sensing" TXB0801 chips. 

3. Mistake: Trying to be too smart

I then realized that the Papilio, the FPGA board I had, didn't have enough I/O pins to connect to the 48 Zorro signals and the 16 (?) pins required for the VGA DAC output. Actually, it had a lot less pins. So I made a huge mistake and decided to use two 16-bit port switching chips and "select" on the fly a window of the Zorro pins that would be relevant at each state of my bus communication loop; I thought I didn't need to access the data pins at the same time as the address pins and because the FPGA runs at a much higher frequency than the Zorro bus, I could first read one part of the address, switch one of the switches via a control pin and then quickly read the other part to get the whole address.

4. Mistake: Using the wrong soldering approach

(no stable signals, noise)

5. Redesign and Breakthrough

6. Picasso96: Writing a Driver

7. Problems to solve

- read arbitration
- XRDY (wait states)

