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
#define MNTVA_COLOR_15BIT    4

typedef volatile struct MNTVARegs {
  u16 fw_version; // 00
  u16 mode;       // 02
  u16 vdiv;  // 04
  u16 screen_w;   // 06
  u16 screen_h;   // 08

  u16 pan_ptr_hi; // 0a
  u16 pan_ptr_lo; // 0c
  u16 hdiv;  // 0e
  u16 blitter_x1; // 10
  u16 blitter_y1; // 12
  u16 blitter_x2; // 14
  u16 blitter_y2; // 16
  u16 blitter_row_pitch; // 18
  u16 blitter_x3; // 1a
  u16 blitter_y3; // 1c
  u16 blitter_rgb_hi;    // 1e
  u16 blitter_rgb_lo;    // 20
  u16 blitter_op_fillrect;  // 22
  u16 blitter_op_copyrect;  // 24
  u16 blitter_op_filltri;   // 26
  
  u16 blitter_src_hi; // 28
  u16 blitter_src_lo; // 2a
  u16 blitter_dst_hi; // 2c
  u16 blitter_dst_lo; // 2e
  
  u16 blitter_colormode; // 30
  u16 videocap_mode; // 32
  
} MNTVARegs;
