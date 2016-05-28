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

//#define debug(x,args...) kprintf("%s:%ld " x "\n", __func__, (uint32)__LINE__ ,##args)

#define debug(x,args...) ;

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
  b->chip_type = 3;
  b->controller_type = 3;
  
  //b->flags = (b->flags&0xffff0000);
  
  b->color_formats = RTG_COLOR_FORMAT_CLUT|RTG_COLOR_FORMAT_RGB565|RTG_COLOR_FORMAT_RGB555|RTG_COLOR_FORMAT_RGB888;
  b->sprite_flags = b->color_formats;

  // TODO read from autoconf/expansion.library
  b->memory = (void*)0x600000;
  //b->memory2 = (void*)0x600000;
  b->memory_size = 0x2f0000;
  //b->memory2_size = 0x2d0000;
  //b->registers = (void*)0x8f0000;
  //b->io = (void*)0x8f0000;

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
  b->fn_rect_copy = rect_copy;
  b->fn_blitter_wait = blitter_wait;

  b->fn_get_pixelclock_index = get_pixelclock_index;
  b->fn_get_pixelclock_hz = get_pixelclock_hz;
  b->fn_set_clock = set_clock;

  b->fn_monitor_switch = monitor_switch;
  
  b->fn_vsync_wait = vsync_wait;
  b->fn_is_vsynced = is_vsynced;
  b->fn_pan = pan;
  b->fn_set_memory_mode = set_memory_mode;
  b->fn_set_write_mask = set_write_mask;
  b->fn_set_clear_mask = set_clear_mask;
  b->fn_set_read_plane = set_read_plane;

  return 1;
}

// placeholder function
void nop() {
  debug("mntgfx: nop()");
}

void init_dac(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7")) {
  debug("mntgfx: init_dac()");
}

// toggle amiga video / rtg
uint32 enable_display(register struct RTGBoard* b asm("a0"), register uint16 enabled asm("d0")) {
  debug("enabled: %x",enabled);
  return 1;
}

void pan(register struct RTGBoard* b asm("a0"), register void* mem asm("a1"), register uint16 w asm("d0"), register int16 x asm("d1"), register int16 y asm("d2"), register uint16 format asm("d7")) {
  debug("");
}

void set_memory_mode(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7")) {
  debug("");
}
void set_read_plane(register struct RTGBoard* b asm("a0"), uint8 p asm("d0")) {
  debug("");
}
void set_write_mask(register struct RTGBoard* b asm("a0"), uint8 m asm("d0")) {
  debug("");
}
void set_clear_mask(register struct RTGBoard* b asm("a0"), uint8 m asm("d0")) {
  debug("");
}
void vsync_wait(register struct RTGBoard* b asm("a0")) {
  debug("");
}
int is_vsynced(register struct RTGBoard* b asm("a0")) {
  debug("");
  return 0;
}
void set_clock(register struct RTGBoard* b asm("a0")) {
  debug("");
}
void set_palette(register struct RTGBoard* b asm("a0"),uint16 idx asm("d0"),uint16 len asm("d1")) {
  debug("");
}

void init_mode(register struct RTGBoard* b asm("a0"), struct ModeInfo* m asm("a1"), int16 border asm("d0")) {
  debug("mntgfx: init_mode");
  b->mode_info = m;
  b->border = border;
}

uint32 is_bitmap_compatible(register struct RTGBoard* b asm("a0"), uint16 format asm("d7")) {
  debug("format: %x",format);
  return 0xffffffff;
}

uint16 get_pitch(register struct RTGBoard* b asm("a0"), uint16 width asm("d0"), uint16 format asm("d7")) {
  debug("width: %x format: %x",width,format);
  return 4096;
}

uint32 map_address(register struct RTGBoard* b asm("a0"), uint32 addr asm("a1")) {
  debug("%lx",addr);
  return addr; // direct mapping
}

uint32 get_pixelclock_index(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7")) {
  debug("");
  // todo update modeinfo
  return 1;
}

uint32 get_pixelclock_hz(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7")) {
  debug("");
  return CLOCK_HZ;
}

uint32 monitor_switch(register struct RTGBoard* b asm("a0"), uint16 state asm("d0")) {
  debug("");
  return state==1;
}

void rect_fill(register struct RTGBoard* b asm("a0"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint32 color asm("d4")) {
  debug("");
  
  *((uint16*)0x8f0020) = x;
  *((uint16*)0x8f0022) = y;
  *((uint16*)0x8f0024) = x+w-1;
  *((uint16*)0x8f0026) = y+h-1;
  
  *((uint16*)0x8f0028) = color;
  *((uint16*)0x8f002a) = 0x1; // enable blitter
}

void rect_copy(register struct RTGBoard* b asm("a0"), register void* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 m asm("d6"), uint16 format asm("d7")) {
  debug("");
  
  *((uint16*)0x8f0020) = dx; // write start point
  *((uint16*)0x8f0022) = dy;
  *((uint16*)0x8f0024) = dx+w-1; // write end point
  *((uint16*)0x8f0026) = dy+h-1;
  *((uint16*)0x8f002c) = x; // read start point
  *((uint16*)0x8f002e) = y;
  *((uint16*)0x8f0030) = x+w-1; // read end point
  *((uint16*)0x8f0032) = y+h-1;
  
  //*((uint16*)0x8f0028) = color;
  *((uint16*)0x8f002a) = 0x2; // enable blitter
}

void blitter_wait(register struct RTGBoard* b asm("a0")) {
  uint16 blitter_busy = 0;
  debug("");
  do {
    blitter_busy = *((volatile uint16*)0x8f002a);
  } while(blitter_busy!=0);
}

ADDTABL_END();
