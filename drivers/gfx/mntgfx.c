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

// REVISION 1.7.2

#include "mntgfx.h"
#include "va2000.h"

#include <exec/io.h>
#include <proto/exec.h>
#include <proto/expansion.h>

// TODO: make this an ENV switch
#define CX_ENABLED 1
#define SCR_CAPMODE 0 // scratch variable 0

//#define debug(x,args...) kprintf("%s:%ld " x "\n", __func__, (uint32)__LINE__ ,##args)
#define debug(x,args...) ;

struct WBStartup *_WBenchMsg;
void _cleanup() {}
void _exit() {}

struct ExecBase* SysBase;
struct Library* GfxBase;

int __UserLibInit(struct Library *libBase)
{
  GfxBase = libBase;
  SysBase = *(struct ExecBase **)4L;

  return 1;
}

void __UserLibCleanup(void) {}

ADDTABL_1(FindCard,a0);
int FindCard(struct RTGBoard* b) {
  struct ConfigDev* cd = NULL;
  uint16 fwrev = 0;

  if ((ExpansionBase = (struct ExpansionBase*)OpenLibrary("expansion.library",0L))==NULL) {
    debug("failed to open expansion.library!");
    return 0;
  }

  if ((cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x1))) {
    debug("MNT VA2000 found.");
    b->memory = (uint8*)(cd->cd_BoardAddr)+0x10000;
    b->memory_size = cd->cd_BoardSize-0x10000;
    b->registers = (uint8*)(cd->cd_BoardAddr);
    fwrev = ((uint16*)b->registers)[0];

    // exit if fw rev not 5 (incompatible memory layout)
    if (fwrev<5) return 0;

    debug("Memory %lx",b->memory);
    debug("Memsize %lx",b->memory_size);
    debug("Regs %lx",b->registers);
    return 1;
  } else {
    debug("MNT VA2000 not found!");
    return 0;
  }
}

ADDTABL_1(InitCard,a0);
int InitCard(struct RTGBoard* b) {
  int max;

  b->self = GfxBase;
  b->exec = SysBase;
  b->name = "mntgfx";
  b->type = 14;
  b->chip_type = 3;
  b->controller_type = 3;

  b->flags = (1<<20)|(1<<12)|(1<<26); // indisplaychain, flickerfixer, directaccess
  b->color_formats = RTG_COLOR_FORMAT_CLUT|RTG_COLOR_FORMAT_RGB565|RTG_COLOR_FORMAT_RGB555|RTG_COLOR_FORMAT_RGB888;
  b->sprite_flags = 0;
  b->bits_per_channel = 8;

  max = 8191;
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
  //b->max_alloc = 0;
  //b->max_alloc_part = 0;

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

  //b->fn_p2c = rect_p2c;
  b->fn_rect_fill = rect_fill;
  b->fn_rect_copy = rect_copy;
  //b->fn_rect_pattern = rect_pattern;
  //b->fn_rect_template = rect_template; // text drawing!
  //b->fn_rect_copy_nomask = rect_copy_nomask; // used for window copying?
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

/*void serp1(char* str, uint32 val) {
  char* tbl="0123456789abcdef";
  char* ptr = str+strlen(str)-10; // 8 digits + crlf
  ptr[0]=tbl[(val&0xf0000000)>>28];
  ptr[1]=tbl[(val&0xf000000)>>24];
  ptr[2]=tbl[(val&0xf00000)>>20];
  ptr[3]=tbl[(val&0xf0000)>>16];
  ptr[4]=tbl[(val&0xf000)>>12];
  ptr[5]=tbl[(val&0xf00)>>8];
  ptr[6]=tbl[(val&0xf0)>>4];
  ptr[7]=tbl[(val&0xf)];
  KPutStr(str);
}*/

// placeholder function
void nop() {
}

void init_dac(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7")) {
}

uint32 enable_display(register struct RTGBoard* b asm("a0"), register uint16 enabled asm("d0")) {
  return 1;
}

void memory_alloc(register struct RTGBoard* b asm("a0"), register uint32 len asm("d0"), register uint16 s1 asm("d1"), register uint16 s2 asm("d2")) {
}

void pan(register struct RTGBoard* b asm("a0"), register void* mem asm("a1"), register uint16 w asm("d0"), register int16 x asm("d1"), register int16 y asm("d2"), register uint16 format asm("d7")) {
  MNTVARegs* registers = b->registers;

  uint32 offset = (mem-(b->memory))>>1; // offset divided by 2 = number of words
  uint16 offhi = (offset&0xffff0000)>>16;
  uint16 offlo = offset&0xfc00;

  registers->pan_ptr_hi = offhi;
  registers->pan_ptr_lo = offlo;
  registers->capture_mode = 0; // CHECKME
  b->scratch[SCR_CAPMODE] = 0;
}

void set_memory_mode(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7")) {
}
void set_read_plane(register struct RTGBoard* b asm("a0"), register uint8 p asm("d0")) {
}
void set_write_mask(register struct RTGBoard* b asm("a0"), register uint8 m asm("d0")) {
}
void set_clear_mask(register struct RTGBoard* b asm("a0"), register uint8 m asm("d0")) {
}
void vsync_wait(register struct RTGBoard* b asm("a0")) {
}
int is_vsynced(register struct RTGBoard* b asm("a0"), register uint8 p asm("d0")) {
  return 1;
}
void set_clock(register struct RTGBoard* b asm("a0")) {
}

void set_palette(register struct RTGBoard* b asm("a0"), uint16 idx asm("d0"), uint16 len asm("d1")) {
  int i;
  int j;
  uint16* palreg_r = (uint16*)(((uint8*)b->registers)+0x200);
  uint16* palreg_g = (uint16*)(((uint8*)b->registers)+0x400);
  uint16* palreg_b = (uint16*)(((uint8*)b->registers)+0x600);

  len+=idx;
  for (i=idx, j=idx*3; i<len; i++) {
    *(palreg_r+i)=b->palette[j];
    *(palreg_g+i)=b->palette[j+1];
    *(palreg_b+i)=b->palette[j+2];
    j+=3;
  }
}

uint16 calc_pitch_bytes(uint16 w, uint16 colormode) {
  uint16 pitch = 2048;
  if (w<=1024) pitch = 1024;

  pitch = pitch<<colormode;
  return pitch;
}

uint16 rtg_to_mnt_colormode(uint16 format) {
  if (format==RTG_COLOR_FORMAT_CLUT) {
    return 0;
  }
  else if (format==9) {
    return 2;
  }
  return 1;
}

uint16 pitch_to_shift(uint16 p) {
  if (p==8192) return 13;
  if (p==4096) return 12;
  if (p==2048) return 11;
  if (p==1024) return 10;
  if (p==512)  return 9;
  if (p==256)  return 8;
  return 0;
}

uint16 get_pitch(register struct RTGBoard* b asm("a0"), uint16 width asm("d0"), uint16 format asm("d7")) {
  return calc_pitch_bytes(width, rtg_to_mnt_colormode(format));
}

void init_modeline(MNTVARegs* registers, uint16 w, uint16 h) {
  if (w==1024 && h==768) {
    registers->h_sync_start = 1048;
    registers->h_sync_end = 1184;
    registers->h_max = 1328;

    registers->v_sync_start = 771;
    registers->v_sync_end = 777;
    registers->v_max = 806;

    registers->pixel_clk_sel = MNTVA_CLK_75MHZ;
  }
  else if (w==1280 && h==720) {
    registers->h_sync_start = 1390;
    registers->h_sync_end = 1430;
    registers->h_max = 1650;

    registers->v_sync_start = 725;
    registers->v_sync_end = 730;
    registers->v_max = 750;

    registers->pixel_clk_sel = MNTVA_CLK_75MHZ;
  }
  else if (w==1280 && h==1024) {
    registers->h_sync_start = 1328;
    registers->h_sync_end = 1440;
    registers->h_max = 1600;

    registers->v_sync_start = 1025;
    registers->v_sync_end = 1028;
    registers->v_max = 1066;

    registers->pixel_clk_sel = MNTVA_CLK_100MHZ;
  }
  else if (w==1920 && h==1080) {
    registers->h_sync_start = 1992;
    registers->h_sync_end = 2000;
    registers->h_max = 2287;

    registers->v_sync_start = 1083;
    registers->v_sync_end = 1088;
    registers->v_max = 1109;

    registers->pixel_clk_sel = MNTVA_CLK_75MHZ;
  }
  else {
    registers->h_sync_start = 840;
    registers->h_sync_end = 968;
    registers->h_max = 1056;

    registers->v_sync_start = 601;
    registers->v_sync_end = 605;
    registers->v_max = 628;

    registers->pixel_clk_sel = MNTVA_CLK_40MHZ;
  }
}

void init_mode_pitch(MNTVARegs* registers, uint16 w, uint16 colormode) {
  uint16 pitch = calc_pitch_bytes(w, colormode)/2; // convert to words
  uint16 pitch_shift = pitch_to_shift(pitch);
  registers->row_pitch = pitch;
  registers->row_pitch_shift = pitch_shift;
}

void init_mode(register struct RTGBoard* b asm("a0"), struct ModeInfo* m asm("a1"), int16 border asm("d0")) {
  MNTVARegs* registers = b->registers;
  uint16 scale = 0;
  uint16 w;
  uint16 h;
  uint16 colormode;

  b->mode_info = m;
  b->border = border;

  if (m->height>360 || m->width>640) {
    scale = 0;
    w = m->width;
    h = m->height;
  } else {
    // small doublescan modes are scaled 2x
    // and output as 640x480 wrapped in 800x600 sync
    scale = 1;
    w = 2*m->width;
    h = 2*m->height;
    if (h<480) h=480;
  }

  colormode = rtg_to_mnt_colormode(b->color_format);

  init_modeline(registers, w, h);
  init_mode_pitch(registers, w, colormode);

  if (colormode==MNTVA_COLOR_8BIT) {
    registers->margin_x = 8; // CHECK
  } else if (colormode==MNTVA_COLOR_32BIT) {
    registers->margin_x = 4;
  } else {
    registers->margin_x = 8;
  }

  registers->colormode = colormode;

  registers->preheat_x = 1;
  registers->scalemode = (scale<<2) | scale; // vscale|hscale
  registers->screen_w = w;
  registers->screen_h = h;

  if (colormode==MNTVA_COLOR_32BIT) {
    // for 32bit color, screenw is 2*hrez (fetch double the data)
    registers->line_w = 4+2*w;
  } else if (colormode==MNTVA_COLOR_8BIT) {
    registers->line_w = w/2; // fetch half the data per line
  }
}

uint32 is_bitmap_compatible(register struct RTGBoard* b asm("a0"), uint16 format asm("d7")) {
  return 0xffffffff;
}

uint32 map_address(register struct RTGBoard* b asm("a0"), uint32 addr asm("a1")) {
  if (addr>(uint32)b->memory && addr < (((uint32)b->memory) + b->memory_size)) {
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
  MNTVARegs* registers = b->registers;
  
  if (state==0 && CX_ENABLED) {
    // capture amiga video to 16bit
    registers->colormode = MNTVA_COLOR_16BIT565;
    registers->scalemode = 4; // scalemode x1:1, y2:1
    registers->pan_ptr_hi = 0xf8; // capture to the end of video memory
    registers->pan_ptr_lo = 0x9c00; // 9c00 = 39 rows of vertical offset

    init_modeline(registers, registers->capture_default_screen_w, registers->capture_default_screen_h);
    init_mode_pitch(registers, registers->capture_default_screen_w, MNTVA_COLOR_16BIT565);
    registers->screen_w = registers->capture_default_screen_w; // default: 640
    registers->screen_h = registers->capture_default_screen_h; // default: 480
    registers->line_w = 0x280;
    registers->margin_x = 0xa;

    registers->capture_mode = 0;
    b->scratch[SCR_CAPMODE] = 0;

    // clear the capture buffer
    registers->blitter_base_hi = 0xf8;
    registers->blitter_base_lo = 0x9c00;
    rect_fill(b, NULL, 0, 0, registers->capture_default_screen_w, registers->capture_default_screen_h, 0);
    blitter_wait(b);

    registers->capture_mode = 1;
    b->scratch[SCR_CAPMODE] = 1;
  } else {
    // rtg mode
    registers->capture_mode = 0;
    b->scratch[SCR_CAPMODE] = 0;
    init_mode(b, b->mode_info, b->border);
  }
  
  return 1-state;
}

void rect_fill(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint32 color asm("d4")) {
  uint16 i=0;
  uint8* ptr;
  uint8 color8;
  uint16 pitch = 1024;
  MNTVARegs* registers = b->registers;
  uint8* gfxmem = (uint8*)b->memory;
  uint32 color_format = b->color_format;
  uint32 offset = 0;
  
  registers->blitter_enable = 0;

  // no blitting in capture mode
  if (b->scratch[SCR_CAPMODE]==1) return;
  
  if (r) {
    offset = (r->memory-(b->memory))>>1;
    registers->blitter_base_hi = (offset&0xffff0000)>>16;
    registers->blitter_base_lo = offset&0xffff;
    pitch = r->pitch;
    gfxmem = (uint8*)r->memory;
    color_format = r->color_format;
  }

  registers->blitter_row_pitch = pitch/2;
  registers->blitter_row_pitch_shift = pitch_to_shift(pitch/2);

  if (color_format==RTG_COLOR_FORMAT_CLUT) {
    color8=color;
    color=(color<<8)|color; // 2 pixels at once
    registers->blitter_rgb16 = color;
    registers->blitter_colormode = MNTVA_COLOR_8BIT;

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
  } else if (color_format==9) {
    // true color
    x*=2;
    w*=2;
    h--;
    w--;
    registers->blitter_rgb32_hi = color>>16;
    registers->blitter_rgb32_lo = color&0xffff;
    registers->blitter_colormode = MNTVA_COLOR_32BIT;
  } else {
    w--;
    h--;
    registers->blitter_rgb16 = color;
    registers->blitter_colormode = MNTVA_COLOR_16BIT565;
  }

  registers->blitter_x1 = x;
  registers->blitter_y1 = y;
  registers->blitter_x2 = x+w;
  registers->blitter_y2 = y+h;

  registers->blitter_enable = 1;
  blitter_wait(b);
}

void rect_copy(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 m asm("d6"), uint16 format asm("d7")) {
  MNTVARegs* registers = b->registers;
  uint16 pitch = 1024;
  uint32 color_format = b->color_format;
  uint32 offset = 0;

  //uint8* gfxmem = (uint8*)b->memory;
  //uint8* ptr;
  //uint8* ptr_src;
  //int i;
  
  registers->blitter_enable = 0;

  // no blitting in capture mode
  if (b->scratch[SCR_CAPMODE]==1) return;

  if (r) {
    offset = (r->memory-(b->memory))>>1;
    registers->blitter_base_hi = (offset&0xffff0000)>>16;
    registers->blitter_base_lo = offset&0xffff;
    pitch = r->pitch;
    color_format = r->color_format;
  }

  registers->blitter_row_pitch = pitch/2;
  registers->blitter_row_pitch_shift = pitch_to_shift(pitch/2);

  if (color_format==RTG_COLOR_FORMAT_CLUT) {
    // fallback as long as 8-bit blitter is unstable
    return b->fn_rect_copy_fallback(b,r,x,y,dx,dy,w,h,m,format);

    // copy odd rows manually
    /*if (x&1 && dx&1) {
      ptr = gfxmem+dy*pitch+dx;
      ptr_src = gfxmem+y*pitch+x;
      for (i=0;i<h;i++) {
        *ptr=*ptr_src;
        ptr+=pitch;
        ptr_src+=pitch;
      }
      x++;
      dx++;
      w--;
    } else if (x&1 || dx&1) {
      // perform the whole blit manually because we
      // can't to byte swapping yet
      b->fn_rect_copy_fallback(b,r,x,y,dx,dy,w,h,m,format);
      return;
    }*/

    /*if (w&1) {
      ptr = gfxmem+dy*pitch+dx+w-1;
      ptr_src = gfxmem+y*pitch+x+w-1;
      for (i=0;i<h;i++) {
        *ptr=*ptr_src;
        ptr+=pitch;
        ptr_src+=pitch;
      }
      w--;
    }

    dx/=2;
    x/=2;
    w/=2;
    if (w<1) return;
    w--;
    h--;*/
  } else if (color_format==9) {
    x*=2;
    dx*=2;
    w*=2;
    w--;
    h--;
  } else {
    w--;
    h--;
  }

  if (dy<y) {
    registers->blitter_y1 = dy;
    registers->blitter_y2 = dy+h;
    registers->blitter_y3 = y;
    registers->blitter_y4 = y+h;
  } else {
    registers->blitter_y1 = dy+h;
    registers->blitter_y2 = dy;
    registers->blitter_y3 = y+h;
    registers->blitter_y4 = y;
  }

  if (dx<x) {
    registers->blitter_x1 = dx;
    registers->blitter_x2 = dx+w;
    registers->blitter_x3 = x;
    registers->blitter_x4 = x+w;
  } else {
    registers->blitter_x1 = dx+w;
    registers->blitter_x2 = dx;
    registers->blitter_x3 = x+w;
    registers->blitter_x4 = x;
  }

  registers->blitter_enable = 2;
  blitter_wait(b);
}

/*void rect_p2c(register struct RTGBoard* b asm("a0"), struct BitMap* bm asm("a1"), struct RenderInfo* r asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 minterm asm("d6"), uint8 mask asm("d7")) {
  serp1("P2C  mask $00000000  ",(uint32)mask);
  serp1("term $00000000  ",(uint32)minterm);
  serp1("P2C  x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("dx   $00000000  ",(uint32)dx);
  serp1("dy   $00000000  ",(uint32)dy);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}

void rect_template(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), struct Template* tp asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint8 mask asm("d4"), uint32 format asm("d7")) {
  serp1("TMPL mask $00000000  ",(uint32)mask);
  serp1("frmt $00000000  ",(uint32)format);
  serp1("TMPL x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}

void rect_pattern(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), struct Pattern* pat asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint8 mask asm("d4"), uint32 format asm("d7")) {
  serp1("PTTN mask $00000000  ",(uint32)mask);
  serp1("frmt $00000000  ",(uint32)format);
  serp1("PTTN x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}

void rect_copy_nomask(register struct RTGBoard* b asm("a0"), struct RenderInfo* sr asm("a1"), struct RenderInfo* dr asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 opcode asm("d6"), uint32 format asm("d7")) {
  serp1("COPC code $00000000  ",(uint32)opcode);
  serp1("frmt $00000000  ",(uint32)format);
  serp1("COPC x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("dx   $00000000  ",(uint32)dx);
  serp1("dy   $00000000  ",(uint32)dy);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}*/

void blitter_wait(register struct RTGBoard* b asm("a0")) {
  volatile uint16 blitter_busy = 0;
  MNTVARegs* registers = b->registers;
  do {
    blitter_busy = registers->blitter_enable;
  } while(blitter_busy!=0);
}

// sprites are currently disabled

/*void sprite_setup(register struct RTGBoard* b asm("a0"), register uint32 enable asm("d0")) {
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
}*/

ADDTABL_END();
