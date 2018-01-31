`timescale 1ns / 1ps
module uart(
   // Outputs
   uart_busy,   // High means UART is transmitting
   uart_tx,     // UART transmit wire
   // Inputs
   uart_wr_i,   // Raise to transmit byte
   uart_dat_i,  // 8-bit data
   sys_clk_i,   // System clock, 75 MHz
   sys_rst_i    // System reset
);

  input uart_wr_i;
  input [7:0] uart_dat_i;
  input sys_clk_i;
  input sys_rst_i;
  
  output uart_busy;
  output uart_tx;

  reg uart_tx_reg;
  reg [3:0] bitcount = 0;
  reg [8:0] shifter = 0;

  wire uart_busy = |bitcount[3:1];
  wire sending = |bitcount;
  assign uart_tx = uart_tx_reg;

  always @(posedge sys_clk_i)
  begin
    if (sys_rst_i) begin
      uart_tx_reg <= 1;
      bitcount <= 0;
      shifter <= 0;
    end else begin
      // just got a new byte
      if (uart_wr_i & ~uart_busy) begin
        shifter <= { uart_dat_i[7:0], 1'h0 };
        bitcount <= (1 + 8 + 2);
      end

      if (sending) begin
        { shifter, uart_tx_reg } <= { 1'h1, shifter };
        bitcount <= bitcount - 1;
      end
    end
  end

endmodule