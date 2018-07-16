set -e
iverilog -DPRELOAD_RAM=1 -DSIMULATION=1 -otestbench.vvp testbench.v ../SDRAM_Controller_v.v glbl.v IOBUF.v ODDR2.v mt48lc16m16a2.v ../va2000.v
vvp -M./verilog-vga-simulator -mvgasim testbench.vvp
