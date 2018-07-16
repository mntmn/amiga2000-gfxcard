Verilog VPI VGA Simulator
=========================

This is an experimental VPI plugin, tested only with Icarus Verilog on Linux,
that approximates the behavior of a VGA-like clocked pixel display
(progressive scan, hsync/vsync signals) with the goal of allowing testing
of video data generation modules.

It is not intended to assist in detecting timing problems in a VGA signal
generator, but rather to test the module that provides the data to the signal
generator.

It is far from real time and isn't optimized for speed at all.

It renders graphics on-screen using SDL. Press the arrow keys to offset the
image, as if turning the X/Y offset knobs on an old CRT monitor. (but since
the refresh rate is so much slower than a real monitor, you'll see the
artifacts that are normally too fast for your eye to see.)

Not extensively tested. Feel free to use it, but take the results with a pinch
of salt.
