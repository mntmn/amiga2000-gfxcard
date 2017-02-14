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

//#define debug(x,args...) ;

struct ExecBase* SysBase;
struct Library* GfxBase;
struct Library* ExpansionBase;

int __UserLibInit(struct Library *libBase)
{
  GfxBase = libBase;
  SysBase = *(struct ExecBase **)4L;

  return 1;
}

void __UserLibCleanup(void)
{
}

ADDTABL_1(FindCard,a0);
int FindCard(struct RTGBoard* b) {
  struct ConfigDev* cd = NULL;
  
  if ((ExpansionBase = (struct Library*)OpenLibrary("expansion.library",0L))==NULL) {
    debug("failed to open expansion.library!");
    return 0;
  }
  
  if (cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x1)) {
    debug("MNT VA2000 rev 1 found.");
    b->memory = (uint8*)(cd->cd_BoardAddr);
    //b->memory_size = 0x01000000; // 0x5f0000;
    b->memory_size = cd->cd_BoardSize-0x10000;
    b->registers = (((uint8*)b->memory)+(cd->cd_BoardSize-0x10000));
    debug("memory %lx",b->memory);
    debug("memsize %lx",b->memory_size);
    debug("regs %lx",b->registers);
    return 1;
  } else {
    debug("MNT VA2000 not found!");
    return 0;
  }
}

ADDTABL_1(InitCard,a0);
int InitCard(struct RTGBoard* b) {
  int max;
  int i=0;

  b->self = GfxBase;
  b->exec = SysBase;
  b->name = "mntgfx";
  b->type = 14;
  b->chip_type = 3;
  b->controller_type = 3;

  // 1|(1<<16)|
  b->flags = (1<<20)|(1<<12); // 0 = has sprite, 16 = 32x32 sprite, 20 = display switch, 12 = flickerfix
  
  b->color_formats = RTG_COLOR_FORMAT_CLUT|RTG_COLOR_FORMAT_RGB565|RTG_COLOR_FORMAT_RGB555|RTG_COLOR_FORMAT_RGB888;
  b->sprite_flags = 0; //b->color_formats;

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

  max = 1080;
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

  /*b->fn_sprite_setup = sprite_setup;
  b->fn_sprite_xy = sprite_xy;
  b->fn_sprite_bitmap = sprite_bitmap;
  b->fn_sprite_colors = sprite_colors;*/

  return 1;
}

// placeholder function
void nop() {
}

void init_dac(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7")) {
}

// toggle amiga video / rtg
uint32 enable_display(register struct RTGBoard* b asm("a0"), register uint16 enabled asm("d0")) {
  return 1;
}

void pan(register struct RTGBoard* b asm("a0"), register void* mem asm("a1"), register uint16 w asm("d0"), register int16 x asm("d1"), register int16 y asm("d2"), register uint16 format asm("d7")) {
  // 480c8010
  
  uint32 offset = (mem-(b->memory))>>1;
  uint8* registers = b->registers;
  uint16 offhi = (offset&0xffff0000)>>16;
  uint16 offlo = offset&0xffff;
  uint16 shift = offlo&0x0fff;
  offlo = offlo&0xf000;
  
  *((uint16*)(registers+0x38))=offhi;
  *((uint16*)(registers+0x3a))=offlo;
  
  //*((uint16*)(registers+0x0c))=8+shift;
}

void set_memory_mode(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7")) {
}
void set_read_plane(register struct RTGBoard* b asm("a0"), uint8 p asm("d0")) {
}
void set_write_mask(register struct RTGBoard* b asm("a0"), uint8 m asm("d0")) {
}
void set_clear_mask(register struct RTGBoard* b asm("a0"), uint8 m asm("d0")) {
}
void vsync_wait(register struct RTGBoard* b asm("a0")) {
}
int is_vsynced(register struct RTGBoard* b asm("a0")) {
  return 0;
}
void set_clock(register struct RTGBoard* b asm("a0")) {
}

void set_palette(register struct RTGBoard* b asm("a0"),uint16 idx asm("d0"),uint16 len asm("d1")) {
  int i;
  int j;
  uint8* registers = (uint8*)b->registers;

  if (b->color_format==RTG_COLOR_FORMAT_CLUT) {
    *((uint16*)(registers+0x48)) = 0;
  } else {
    *((uint16*)(registers+0x48)) = 1;
  }
  
  len+=idx;
  for (i=idx, j=idx*3; i<len; i++) {
    *((uint16*)(registers+0x200)+i)=b->palette[j];
    *((uint16*)(registers+0x400)+i)=b->palette[j+1];
    *((uint16*)(registers+0x600)+i)=b->palette[j+2];
    j+=3;
  }
}

void init_mode(register struct RTGBoard* b asm("a0"), struct ModeInfo* m asm("a1"), int16 border asm("d0")) {
  uint8* registers = (uint8*)b->registers;
  uint16 scale = 0;
  uint16 w;
  uint16 h;
  uint16 pitch = 1024;
  uint16 pitch_shift = 10;
  uint8 compat_mode = 0;
  
  b->mode_info = m;
  b->border = border;

  if (m->height>360 || m->width>640) {
    scale = 0;
    w = m->width;
    h = m->height;
  } else {
    scale = 1;
    w = m->width+m->width;
    h = m->height+m->height;
    
    if (h<480) h=480;
  }

  if (m->width==1024 && m->height==768) {
    *((uint16*)(registers+0x70)) = 1048;
    *((uint16*)(registers+0x72)) = 1184;
    *((uint16*)(registers+0x74)) = 1328;
    
    *((uint16*)(registers+0x76)) = 771;
    *((uint16*)(registers+0x78)) = 777;
    *((uint16*)(registers+0x7a)) = 806;
    
    *((uint16*)(registers+0x7c)) = 0; // 75mhz
    
    pitch = 1024;
    pitch_shift = 10;
  }
  else if (m->width==1280 && m->height==720) {
    *((uint16*)(registers+0x70)) = 1390;
    *((uint16*)(registers+0x72)) = 1430;
    *((uint16*)(registers+0x74)) = 1650;
    
    *((uint16*)(registers+0x76)) = 725;
    *((uint16*)(registers+0x78)) = 730;
    *((uint16*)(registers+0x7a)) = 750;
    
    *((uint16*)(registers+0x7c)) = 0; // 75mhz
    
    pitch = 2048;
    pitch_shift = 11;
  }
  else if (m->width==1280 && m->height==1024) {
    *((uint16*)(registers+0x70)) = 1328;
    *((uint16*)(registers+0x72)) = 1440;
    *((uint16*)(registers+0x74)) = 1600;
    
    *((uint16*)(registers+0x76)) = 1025;
    *((uint16*)(registers+0x78)) = 1028;
    *((uint16*)(registers+0x7a)) = 1066;
    
    *((uint16*)(registers+0x7c)) = 3; // 100mhz
    
    pitch = 2048;
    pitch_shift = 11;
  }
  else if (m->width==1920 && m->height==1080) {
    *((uint16*)(registers+0x70)) = 1992;
    *((uint16*)(registers+0x72)) = 2000;
    *((uint16*)(registers+0x74)) = 2287;
    
    *((uint16*)(registers+0x76)) = 1083;
    *((uint16*)(registers+0x78)) = 1088;
    *((uint16*)(registers+0x7a)) = 1109;
    
    *((uint16*)(registers+0x7c)) = 0; // 75mhz
    
    pitch = 2048;
    pitch_shift = 11;
  }
  else {
    *((uint16*)(registers+0x70)) = 832; // 856;
    *((uint16*)(registers+0x72)) = 896; // 976;
    *((uint16*)(registers+0x74)) = 1048; // 1050;
    
    *((uint16*)(registers+0x76)) = 601; // 637;
    *((uint16*)(registers+0x78)) = 604; // 643;
    *((uint16*)(registers+0x7a)) = 631; // 666;
    
    *((uint16*)(registers+0x7c)) = 1; // 50mhz

    pitch = 1024;
    pitch_shift = 10;
  }
  
  if (b->color_format==RTG_COLOR_FORMAT_CLUT) {
    *((uint16*)(registers+0x48)) = 0; // colormode
    if (scale>0) {
      *((uint16*)(registers+0x10)) = 7; // preheat (required for 8bit modes)
    } else {
      *((uint16*)(registers+0x10)) = 3; // preheat (required for 8bit modes)
    }

    pitch/=2;
    pitch_shift--;    
  } else if (b->color_format==9) {
    *((uint16*)(registers+0x48)) = 2; // colormode
    *((uint16*)(registers+0x10)) = 1; // preheat
  } else {
    *((uint16*)(registers+0x48)) = 1; // colormode
    *((uint16*)(registers+0x10)) = 1; // preheat
  }

  if (b->color_format==9) {
    // for 32bit color, screenw is 2*hrez (fetch double the data)
    pitch+=pitch;
    pitch_shift+=1;
  }
  
  *((uint16*)(registers+0x58)) = pitch;
  *((uint16*)(registers+0x5c)) = pitch_shift;
  if (b->color_format==9) {
    *((uint16*)(registers+0x0c)) = 4; // margin_x
  } else {
    *((uint16*)(registers+0x0c)) = 8; // margin_x
  }
  // FIXME
  *((uint16*)(registers+0x10)) = 1; // preheat_x
  
  *((uint16*)(registers+4)) = (scale<<2) | scale; // vscale|hscale
  *((uint16*)(registers+6)) = w;
  *((uint16*)(registers+8)) = h;

  if (b->color_format==9) {
    // for 32bit color, screenw is 2*hrez (fetch double the data)
    *((uint16*)(registers+2)) = w+w+4;
  }
}

uint32 is_bitmap_compatible(register struct RTGBoard* b asm("a0"), uint16 format asm("d7")) {
  //debug("format: %x",format);
  return 0xffffffff;
}

uint16 get_pitch(register struct RTGBoard* b asm("a0"), uint16 width asm("d0"), uint16 format asm("d7")) {
  if (format==RTG_COLOR_FORMAT_CLUT) {
    //if (width==320) return 320;
    if (width<=1024) return 1024;
    if (width<=2048) return 2048;
  }
  else if (format==9) {
    if (width<=1024) return 1024*4;
    if (width<=2048) return 2048*4;
  }
  else {
    if (width<=1024) return 1024*2;
    if (width<=2048) return 2048*2;
  }
  return 1024*2;
}

uint32 map_address(register struct RTGBoard* b asm("a0"), uint32 addr asm("a1")) {
  if (addr>(uint32)b->memory && addr < (((uint32)b->memory) + b->memory_size)) {
    // FIXME
    addr=addr&0xfffff000;
  }
  return addr; // direct mapping
}

uint32 get_pixelclock_index(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7")) {
  mode->pixel_clock_hz = CLOCK_HZ;
  mode->clock = 0;
  mode->clock_div = 1;
  return 0;
}

uint32 get_pixelclock_hz(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7")) {
  return CLOCK_HZ;
}

uint32 monitor_switch(register struct RTGBoard* b asm("a0"), uint16 state asm("d0")) {
  uint8* registers = (uint8*)b->registers;

  if (state==0) {
    // capture amiga videuo to 16bit
    *((uint16*)(registers+0x48)) = 1; // colormode 565
    *((uint16*)(registers+0x04)) = 4; // scalemode x1:1, y2:1
    *((uint16*)(registers+0x4e)) = 1; // capture on
    *((uint16*)(registers+0x38)) = 0xf8;
    *((uint16*)(registers+0x3a)) = 0xa000; // display (pan) pointer

    *((uint16*)(registers+0x06)) = 640; // hrez
    *((uint16*)(registers+0x08)) = 480; // vrez
    *((uint16*)(registers+0x70)) = 832;
    *((uint16*)(registers+0x72)) = 896;
    *((uint16*)(registers+0x74)) = 1048;
    *((uint16*)(registers+0x76)) = 601;
    *((uint16*)(registers+0x78)) = 604;
    *((uint16*)(registers+0x7a)) = 631;
    *((uint16*)(registers+0x7c)) = 1; // 40mhz
    
    *((uint16*)(registers+0x02)) = 0x280; // screenw

    *((uint16*)(registers+0x58)) = 1024;
    *((uint16*)(registers+0x5c)) = 10;
    
  } else {
    // rtg mode
    *((uint16*)(registers+0x4e)) = 0; // capture off
    init_mode(b,b->mode_info,b->border);
  }
  
  return 1-state;
}

void rect_fill(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint32 color asm("d4")) {
  //debug("");
  uint16 i=0;
  uint8* ptr;
  uint8 color8;
  uint16 pitch = 1024;
  uint8* registers = (uint8*)b->registers;
  uint8* gfxmem = (uint8*)b->memory;
  
  if (r) {
    uint32 offset = (r->memory-(b->memory))>>1;
    uint16 offhi = (offset&0xffff0000)>>16;
    uint16 offlo = offset&0xffff;
    *((uint16*)(registers+0x1c)) = offhi;
    *((uint16*)(registers+0x1e)) = offlo;
    pitch = r->pitch;
    gfxmem = (uint8*)r->memory;
  }
  
  if (b->color_format==RTG_COLOR_FORMAT_CLUT) {
    color8=color;
    color=(color<<8)|color; // 2 pixels at once
    *((uint16*)(registers+0x28)) = color;

    // draw odd lines manually
    if (x&1) {
      ptr = gfxmem+y*pitch+x;
      for (i=0;i<h;i++) {
        *ptr=color8;
        ptr+=pitch;
      }
      x++;
      w--;
    }
    
    if (w&1) {
      ptr = gfxmem+y*pitch+x+w-1;
      for (i=0;i<h;i++) {
        *ptr=color8;
        ptr+=pitch;
      }
      w--;
    }

    x/=2;
    w/=2;
    if (w==0) return;
    w--;
    h--;
  } else if (b->color_format==9) {
    // true color
    x*=2;
    w--;
    w*=2;
    h--;
    *((uint16*)(registers+0x34)) = color>>16; // 32 bit color reg
    *((uint16*)(registers+0x36)) = color;
  } else {
    w--;
    h--;
    *((uint16*)(registers+0x28)) = color;
  }

  *((uint16*)(registers+0x20)) = x;
  *((uint16*)(registers+0x22)) = y;
  *((uint16*)(registers+0x24)) = x+w;
  *((uint16*)(registers+0x26)) = y+h;
  
  *((uint16*)(registers+0x2a)) = 0x1; // enable blitter
}

void rect_copy(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 m asm("d6"), uint16 format asm("d7")) {
  uint16 blitter_busy = 0;
  //debug("");
  uint8* registers = (uint8*)b->registers;
  uint16 pitch = 1024;

  if (r) {
    uint32 offset = (r->memory-(b->memory))>>1;
    uint16 offhi = (offset&0xffff0000)>>16;
    uint16 offlo = offset&0xffff;
    *((uint16*)(registers+0x1c)) = offhi;
    *((uint16*)(registers+0x1e)) = offlo;
    pitch = r->pitch;
  }
  
  if (b->color_format==RTG_COLOR_FORMAT_CLUT) {
    dx/=2;
    x/=2;
    w/=2;
    h--;
  } else if (b->color_format==9) {
    x*=2;
    dx*=2;
    w*=2;
    h--;
  } else {
    if (dx>=x) w--;
    h--;
  }

  if (dy<y) {
    *((uint16*)(registers+0x22)) = dy;
    *((uint16*)(registers+0x26)) = dy+h;
    *((uint16*)(registers+0x2e)) = y;
    *((uint16*)(registers+0x32)) = (y+h);
  } else {
    *((uint16*)(registers+0x22)) = dy+h;
    *((uint16*)(registers+0x26)) = dy;
    *((uint16*)(registers+0x2e)) = (y+h);
    *((uint16*)(registers+0x32)) = (y);
  }

  if (dx<x) {
    *((uint16*)(registers+0x20)) = dx; // write start point
    *((uint16*)(registers+0x24)) = dx+w; // write end point
    *((uint16*)(registers+0x2c)) = x; // read start point
    *((uint16*)(registers+0x30)) = x+w; // read end point
  } else {
    *((uint16*)(registers+0x20)) = dx+w; // write start point
    *((uint16*)(registers+0x24)) = dx; // write end point
    *((uint16*)(registers+0x2c)) = x+w; // read start point
    *((uint16*)(registers+0x30)) = x; // read end point
  }
  
  *((uint16*)(registers+0x2a)) = 0x2; // enable blitter
}

void blitter_wait(register struct RTGBoard* b asm("a0")) {
  uint16 blitter_busy = 0;
  //debug("");
  uint8* registers = (uint8*)b->registers;
  do {
    blitter_busy = *((volatile uint16*)(registers+0x2a));
  } while(blitter_busy!=0);
}

void sprite_setup(register struct RTGBoard* b asm("a0"), register uint32 enable asm("d0")) {
  //debug("");
}

void sprite_xy(register struct RTGBoard* b asm("a0")) {
  uint8* registers = (uint8*)b->registers;
  uint16 x = b->cursor_x;
  uint16 y = b->cursor_y;
  
  *((volatile uint16*)(registers+0x40)) = x;
  *((volatile uint16*)(registers+0x42)) = y;
  *((volatile uint16*)(registers+0x44)) = x+(b->cursor_w)-1;
  *((volatile uint16*)(registers+0x46)) = y+(b->cursor_h)-1;
}

void sprite_bitmap(register struct RTGBoard* b asm("a0")) {
  // sprites are stored as 2-bitplane lines
  // 0x00000000 0x00000000 <- 1 line
  uint32* s32;
  volatile uint32* d32;
  volatile uint32* d32b;
  uint16* s16;
  volatile uint16* d16;
  volatile uint16* d16b;
  int y;

  if (0) {
    s32=(uint32*)b->cursor_sprite_bitmap;
    d32=(volatile uint32*)b->registers+0x800;
    d32b=(volatile uint32*)b->registers+0x880; // bitplane 2

    for (y=0; y<32; y++) {
      *d32++ =*s32++;
      *d32b++=*s32++;
    }
  } else {
    s16=(uint16*)(b->cursor_sprite_bitmap+4);
    d16=(volatile uint16*)(((uint8*)b->registers)+0x800);
    d16b=(volatile uint16*)(((uint8*)b->registers)+0x880); // bitplane 2

    for (y=0; y<32; y++) {
      *d16++=*s16++;
      *d16b++=*s16++;
    }
  }
}

void sprite_colors(register struct RTGBoard* b asm("a0"), register uint8 idx asm("d0"),
  register uint8 red asm("d1"), register uint8 green asm("d2"), register uint8 blue asm("d3")) {

  uint8* registers = (uint8*)b->registers;
  //debug("%x %x %x %x",idx,red,green,blue);

  if (idx==0) idx=1;
  else if (idx==1) idx=0;
  
  *((volatile uint16*)(registers+0x922+2*idx))=blue;
  *((volatile uint16*)(registers+0x912+2*idx))=green;
  *((volatile uint16*)(registers+0x902+2*idx))=red;
}

ADDTABL_END();
