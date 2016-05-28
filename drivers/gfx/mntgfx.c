/*
 * Amiga Gfx Card Driver (mntgfx.card)
 * Copyright (C) 2016, Lukas F. Hartmann <lukas@mntmn.com>
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

#include "mntgfx.h"

#define debug(x,args...) kprintf("%s:%ld " x "\n", __func__, (uint32)__LINE__ ,##args)

static struct ExecBase* SysBase;
static struct Library* GfxBase;

int __UserLibInit(struct Library *libBase)
{
  debug("");
  GfxBase = libBase;
  SysBase = *(struct ExecBase **)4L;

  return 1;
}

void __UserLibCleanup(void)
{
  debug("");
}

ADDTABL_1(FindCard,a0);
int FindCard(struct RTGBoard* b) {
  debug("");
  return 1;
}

ADDTABL_1(InitCard,a0);
int InitCard(struct RTGBoard* b) {
  int max;

  debug("mntgfx: InitCard");
  
  b->self = GfxBase;
  b->exec = SysBase;
  b->name = "mntgfx";
  b->type = 14;
  b->chip_type = 0;
  b->controller_type = 0;
  
  b->flags = (b->flags&0xffff0000);
  b->sprite_flags = 0;

  b->color_formats = RTG_COLOR_FORMAT_CLUT|RTG_COLOR_FORMAT_RGB565|RTG_COLOR_FORMAT_RGB555|RTG_COLOR_FORMAT_RGB888;

  // TODO read from autoconf/expansion.library
  b->memory = (void*)0x600000;
  b->memory2 = (void*)0x600000;
  b->memory_size = 0x2d0000;
  b->memory2_size = 0x2d0000;
  b->registers = (void*)0x8f0000;
  b->io = (void*)0x8f0000;

  // TODO true color
  b->bits_per_channel = 6;

  max = 4095;
  b->max_bitmap_w_planar = max;
  b->max_bitmap_w_clut = max;
  b->max_bitmap_w_16bit = max;
  b->max_bitmap_w_24bit = max;
  b->max_bitmap_w_32bit = max;
  
  b->max_bitmap_h_planar = max;
  b->max_bitmap_h_clut = max;
  b->max_bitmap_h_16bit = max;
  b->max_bitmap_h_24bit = max;
  b->max_bitmap_h_32bit = max;

  max = 1920;
  b->max_res_w_planar = max;
  b->max_res_w_clut = max;
  b->max_res_w_16bit = max;
  b->max_res_w_24bit = max;
  b->max_res_w_32bit = max;

  max = 720;
  b->max_res_h_planar = max;
  b->max_res_h_clut = max;
  b->max_res_h_16bit = max;
  b->max_res_h_24bit = max;
  b->max_res_h_32bit = max;

  // no alloc yet
  b->max_alloc = 0;
  b->max_alloc_part = 0;

  b->clock_ram = CLOCK_HZ;
  b->num_pixelclocks_planar = 1;
  b->num_pixelclocks_clut = 1;
  b->num_pixelclocks_16bit = 1;
  b->num_pixelclocks_24bit = 1;
  b->num_pixelclocks_32bit = 1;

  b->fn_init_dac = init_dac;
  b->fn_init_mode = init_mode;

  b->fn_get_pitch = get_pitch;
  b->fn_map_address = map_address;
  
  b->fn_is_bitmap_compatible = is_bitmap_compatible;
  b->fn_set_palette = set_palette;
  b->fn_enable_display = enable_display;

  b->fn_rect_fill = rect_fill;
  b->fn_blitter_wait = blitter_wait;

  b->fn_get_pixelclock_index = get_pixelclock_index;
  b->fn_get_pixelclock_hz = get_pixelclock_hz;
  b->fn_set_clock = set_clock;

  b->fn_monitor_switch = monitor_switch;

  b->fn_vsync_wait = vsync_wait;
  b->fn_pan = pan;
  b->fn_set_memory_mode = set_memory_mode;
  b->fn_set_write_mask = set_write_mask;
  b->fn_set_clear_mask = set_clear_mask;
  b->fn_set_read_plane = set_read_plane;

  return 1;
}

// placeholder function
ADDTABL_0(nop);
void nop() {
  debug("mntgfx: nop()");
}

ADDTABL_2(init_dac,a0,d7);
void init_dac(struct RTGBoard* b, uint16 format) {
  debug("mntgfx: init_dac()");
}

// toggle amiga video / rtg
ADDTABL_2(enable_display,a0,d0);
uint32 enable_display(struct RTGBoard* b, uint16 enabled) {
  debug("enabled: %x",enabled);
  return 1;
}

ADDTABL_6(pan,a0,a1,d0,d1,d2,d7);
void pan(struct RTGBoard* b, void* mem, uint16 w, int16 x, int16 y, uint16 format) {
  debug("");
}

ADDTABL_2(set_memory_mode,a0,d7);
void set_memory_mode(register struct RTGBoard* b asm("a0"), uint16 format) {
  debug("");
}
ADDTABL_2(set_read_plane,a0,d0);
void set_read_plane(struct RTGBoard* b, uint8 p) {
  debug("");
}
ADDTABL_2(set_write_mask,a0,d0);
void set_write_mask(struct RTGBoard* b, uint8 m) {
  debug("");
}
ADDTABL_2(set_clear_mask,a0,d0);
void set_clear_mask(struct RTGBoard* b, uint8 m) {
  debug("");
}
ADDTABL_1(vsync_wait,a0);
void vsync_wait(struct RTGBoard* b) {
  debug("");
}
ADDTABL_1(set_clock,a0);
void set_clock(struct RTGBoard* b) {
  debug("");
}
ADDTABL_3(set_palette,a0,d0,d1);
void set_palette(struct RTGBoard* b,uint16 idx,uint16 len) {
  debug("");
}

ADDTABL_3(init_mode,a0,a1,d0);
void init_mode(struct RTGBoard* b, struct ModeInfo* m, int16 border) {
  debug("mntgfx: init_mode");
  b->mode_info = m;
  b->border = border;
}

ADDTABL_2(is_bitmap_compatible,a0,d7);
uint32 is_bitmap_compatible(struct RTGBoard* b, uint16 format) {
  debug("format: %x",format);
  return 0xffffffff;
}

ADDTABL_3(get_pitch,a0,d0,d7);
uint16 get_pitch(struct RTGBoard* b, uint16 width, uint16 format) {
  debug("width: %x format: %x",width,format);
  return 4096;
}

ADDTABL_2(map_address,a0,a1);
uint32 map_address(struct RTGBoard* b, uint32 addr) {
  debug("%lx",addr);
  return addr; // direct mapping
}

ADDTABL_4(get_pixelclock_index,a0,a1,d0,d7);
uint32 get_pixelclock_index(struct RTGBoard* b, struct ModeInfo* mode, int32 clock, uint16 format) {
  debug("");
  // todo update modeinfo
  return 0;
}

ADDTABL_4(get_pixelclock_hz,a0,a1,d0,d7);
uint32 get_pixelclock_hz(struct RTGBoard* b, struct ModeInfo* mode, int32 clock, uint16 format) {
  debug("");
  return CLOCK_HZ;
}

ADDTABL_2(monitor_switch,a0,d0);
uint32 monitor_switch(struct RTGBoard* b, uint16 state) {
  debug("");
  return state;
}

ADDTABL_6(rect_fill,a0,d0,d1,d2,d3,d4);
void rect_fill(struct RTGBoard* b, uint16 x, uint16 y, uint16 w, uint16 h, uint32 color) {
  debug("");
  
  *((uint16*)0x8f0020) = x;
  *((uint16*)0x8f0022) = y;
  *((uint16*)0x8f0024) = x+w-1;
  *((uint16*)0x8f0026) = y+h-1;
  
  *((uint16*)0x8f0028) = color;
  *((uint16*)0x8f002a) = 0xffff; // enable blitter
}

ADDTABL_1(blitter_wait,a0);
void blitter_wait(struct RTGBoard* b) {
  debug("");
  while(*((uint16*)0x8f002a)) {};
}

ADDTABL_END();
