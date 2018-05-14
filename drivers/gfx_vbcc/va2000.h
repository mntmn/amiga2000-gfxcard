/*
 * MNT VA2000 Amiga Gfx Card Driver (mntgfx.card)
 * Copyright (C) 2016-2017, Lukas F. Hartmann <lukas@mntmn.com>
 *
 * More Info: http://mntmn.com/va2000
 *
 * Licensed under the MIT License:
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#define uint8_t unsigned char
#define uint16_t unsigned short
#define uint32_t unsigned long

#define u16 uint16_t
#define u32 uint32_t

#define MNTVA_COLOR_8BIT     0
#define MNTVA_COLOR_16BIT565 1
#define MNTVA_COLOR_32BIT    2
#define MNTVA_COLOR_1BIT     3

#define MNTVA_CLK_75MHZ 0
#define MNTVA_CLK_40MHZ 1
#define MNTVA_CLK_100MHZ 3

typedef volatile struct MNTVARegs {
  u16 fw_version; // 00
  u16 line_w;     // 02
  u16 scalemode;  // 04
  u16 screen_w;   // 06
  u16 screen_h;   // 08

  u16 refresh_max; // 0a
  u16 margin_x;    // 0c
  u16 colormode;   // 0e
  u16 safe_x1;     // 10
  u16 reserved_12; // 12
  u16 safe_x2;     // 14
  u16 reserved_16; // 16
  u16 ram_fetch_delay2_max; // 18
  u16 fetch_preroll; // 1a

  u16 blitter_row_pitch; // 1c
  u16 blitter_colormode; // 1e
  u16 blitter_x1;        // 20
  u16 blitter_y1;        // 22
  u16 blitter_x2;        // 24
  u16 blitter_y2;        // 26
  u16 blitter_rgb16;     // 28
  u16 blitter_enable;    // 2a

  u16 blitter_x3; // 2c
  u16 blitter_y3; // 2e
  u16 blitter_x4; // 30
  u16 blitter_y4; // 32
  
  u16 blitter_rgb32_hi; // 34,36
  u16 blitter_rgb32_lo;
  u16 pan_ptr_hi; // 38,3a
  u16 pan_ptr_lo;
  
  u16 videocap_prex;    // 3c
  u16 videocap_voffset; // 3e
  
  u16 blitter_src_hi; // 40
  u16 blitter_src_lo; // 42
  u16 blitter_dst_hi; // 44
  u16 blitter_dst_lo; // 46
  
  u16 reserved_48;   // 48
  u16 dcm7_psincdec; // 4a
  u16 dcm7_rst;      // 4c
  u16 capture_mode;  // 4e

  u16 capture_w; // 50
  u16 capture_h; // 52
  u16 capture_default_screen_w; // 54
  u16 capture_default_screen_h; // 56

  u16 row_pitch;       // 58
  u16 reserved_5a;     // 5a
  u16 row_pitch_shift; // 5c

  u16 vsync;     // 5e
  
  u16 busy;      // 60 write: reset
  u16 read;      // 62
  u16 write;     // 64
  u16 handshake; // 66
  u16 addr_hi;   // 68
  u16 addr_lo;   // 6a
  u16 data_in;   // 6c
  u16 data_out;  // 6e data in upper byte!

  u16 h_sync_start; // 70
  u16 h_sync_end;   // 72
  u16 h_max;        // 74
  u16 v_sync_start; // 76
  u16 v_sync_end;   // 78
  u16 v_max;        // 7a

  u16 pixel_clk_sel; // 7c

  u16 reserved_7e;
  
} MNTVARegs;
