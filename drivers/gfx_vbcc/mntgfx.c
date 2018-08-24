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

/* REVISION 1.9.0 */

#include "mntgfx.h"
#include "va2000.h"

#include <proto/exec.h>
#include <proto/expansion.h>

#include <exec/types.h>
#include <exec/memory.h>
#include <exec/libraries.h>
#include <exec/execbase.h>
#include <exec/resident.h>
#include <exec/initializers.h>
#include <clib/debug_protos.h>

static ULONG LibStart(void) {
  return(-1);
}

static const char LibraryName[] = "mntgfx.card";
static const char LibraryID[]   = "$VER: mntgfx.card 1.90 (2018-07-16)\r\n";

struct MNTGFXBase* OpenLib( __reg("a6") struct MNTGFXBase *MNTGFXBase);
BPTR __saveds CloseLib( __reg("a6") struct MNTGFXBase *MNTGFXBase);
BPTR __saveds ExpungeLib( __reg("a6") struct MNTGFXBase *exb);
ULONG ExtFuncLib(void);
struct MNTGFXBase* InitLib(__reg("a6") struct ExecBase    *sysbase,
                                    __reg("a0") BPTR          seglist,
                                    __reg("d0") struct MNTGFXBase *exb);

static const APTR FuncTab[] = {
  (APTR)OpenLib,
  (APTR)CloseLib,
  (APTR)ExpungeLib,
  (APTR)ExtFuncLib,

  (APTR)FindCard,
  (APTR)InitCard,
  (APTR)((LONG)-1)
};

struct InitTable
{
  ULONG LibBaseSize;
  APTR  FunctionTable;
  APTR  DataTable;
  APTR  InitLibTable;
};

static struct InitTable InitTab = {
  (ULONG) sizeof(struct MNTGFXBase),
  (APTR) FuncTab,
  (APTR) NULL,
  (APTR) InitLib
};

static const struct Resident ROMTag = {
	RTC_MATCHWORD,
  &ROMTag,
  &ROMTag + 1,
  RTF_AUTOINIT,
	83,
  NT_LIBRARY,
  0,
  (char *)LibraryName,
  (char *)LibraryID,
  (APTR)&InitTab
};

//void KPrintF(__reg("a0")char* str,__reg("a1")void* vals);
static struct MNTGFXBase *MNTGFXBase;

struct MNTGFXBase* InitLib(__reg("a6") struct ExecBase      *sysbase,
                                          __reg("a0") BPTR            seglist,
                                          __reg("d0") struct MNTGFXBase   *exb)
{
  MNTGFXBase = exb;
  //MNTGFXBase->sysBase = sysbase;
  //MNTGFXBase->segList = seglist;
  return(MNTGFXBase);
}

struct MNTGFXBase* OpenLib(__reg("a6") struct MNTGFXBase *MNTGFXBase)
{
  MNTGFXBase->libNode.lib_OpenCnt++;
  MNTGFXBase->libNode.lib_Flags &= ~LIBF_DELEXP;

  return(MNTGFXBase);
}

BPTR __saveds CloseLib(__reg("a6") struct MNTGFXBase *MNTGFXBase)
{
  MNTGFXBase->libNode.lib_OpenCnt--;

  if(!MNTGFXBase->libNode.lib_OpenCnt) {
    if(MNTGFXBase->libNode.lib_Flags & LIBF_DELEXP) {
      return( ExpungeLib(MNTGFXBase) );
    }
  }
  return(NULL);
}

BPTR __saveds ExpungeLib(__reg("a6") struct MNTGFXBase *exb)
{
  struct MNTGFXBase *MNTGFXBase = exb;
  BPTR seglist;
  struct ExecBase *SysBase = *(struct ExecBase **)4L;
  
  if(!MNTGFXBase->libNode.lib_OpenCnt) {
    ULONG negsize, possize, fullsize;
    UBYTE *negptr = (UBYTE *) MNTGFXBase;

    seglist = MNTGFXBase->segList;

    Remove((struct Node *)MNTGFXBase);

    //L_CloseLibs();

    negsize  = MNTGFXBase->libNode.lib_NegSize;
    possize  = MNTGFXBase->libNode.lib_PosSize;
    fullsize = negsize + possize;
    negptr  -= negsize;

    FreeMem(negptr, fullsize);
    return(seglist);
  }

  MNTGFXBase->libNode.lib_Flags |= LIBF_DELEXP;
  return(NULL);
}

ULONG ExtFuncLib(void)
{
  return(NULL);
}

#define CX_ENABLED 1
#define SCR_CAPMODE 0 // scratch variable 0

int FindCard(__reg("a0") struct RTGBoard* b) {
  struct ConfigDev* cd = NULL;
  uint16 fwrev = 0;
  struct ExpansionBase *ExpansionBase = NULL;
  struct ExecBase *SysBase = *(struct ExecBase **)4L;

  if ((ExpansionBase = (struct ExpansionBase*)OpenLibrary("expansion.library",0L))==NULL) {
    //KPrintF("failed to open expansion.library!\n");
    return 0;
  }

  if ((cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x1))) {
    //KPrintF("MNT VA2000 found.\n");
    b->memory = (uint8*)(cd->cd_BoardAddr)+0x10000;
    b->memory_size = cd->cd_BoardSize-0x10000;
    b->registers = (uint8*)(cd->cd_BoardAddr);
    fwrev = ((uint16*)b->registers)[0];

    // exit if fw rev not 5 (incompatible memory layout)
    if (fwrev<5) {
      //KPrintF("Error: incompatible firmware\n");
      return 0;
    }
    
    //debug("Memory %lx",b->memory);
    //debug("Memsize %lx",b->memory_size);
    //debug("Regs %lx",b->registers);
    return 1;
  } else {
    //KPrintF("MNT VA2000 not found!\n");
    return 0;
  }
}

int InitCard(__reg("a0") struct RTGBoard* b) {
  int max;
  struct ExecBase *SysBase = *(struct ExecBase **)4L;

  b->self = MNTGFXBase;
  b->exec = SysBase;
  b->name = "mntgfx";
  b->type = 14;
  b->chip_type = 3;
  b->controller_type = 3;

  b->flags = (1<<20)|(1<<12)|(1<<26); // indisplaychain, flickerfixer, directaccess
  b->color_formats = 1|2|512|1024|2048;
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

  b->fn_init_dac = (void*)init_dac;
  b->fn_init_mode = (void*)init_mode;

  b->fn_get_pitch = (void*)get_pitch;
  b->fn_map_address = (void*)map_address;

  b->fn_is_bitmap_compatible = (void*)is_bitmap_compatible;
  b->fn_set_palette = (void*)set_palette;
  b->fn_enable_display = (void*)enable_display;

  //b->fn_p2c = rect_p2c;
  b->fn_rect_fill = (void*)rect_fill;
  b->fn_rect_copy = (void*)rect_copy;
  //b->fn_rect_pattern = rect_pattern;
  //b->fn_rect_template = rect_template; // text drawing!
  //b->fn_rect_copy_nomask = rect_copy_nomask; // used for window copying?
  b->fn_blitter_wait = (void*)blitter_wait;

  b->fn_get_pixelclock_index = (void*)get_pixelclock_index;
  b->fn_get_pixelclock_hz = (void*)get_pixelclock_hz;
  b->fn_set_clock = (void*)set_clock;

  b->fn_monitor_switch = (void*)monitor_switch;

  b->fn_vsync_wait = (void*)vsync_wait;
  b->fn_is_vsynced = (void*)is_vsynced;
  b->fn_pan = (void*)pan;
  b->fn_set_memory_mode = (void*)set_memory_mode;
  b->fn_set_write_mask = (void*)set_write_mask;
  b->fn_set_clear_mask = (void*)set_clear_mask;
  b->fn_set_read_plane = (void*)set_read_plane;
  
  /*b->fn_sprite_setup = sprite_setup;
  b->fn_sprite_xy = sprite_xy;
  b->fn_sprite_bitmap = sprite_bitmap;
  b->fn_sprite_colors = sprite_colors;*/

  return 1;
}

// placeholder function
void nop() {
}

void init_dac(__reg("a0") struct RTGBoard* b,__reg("d7")  uint16 format) {
}

uint32 enable_display(__reg("a0") struct RTGBoard* b,__reg("d0")  uint16 enabled) {
  return 1;
}

void memory_alloc(__reg("a0") struct RTGBoard* b,__reg("d0")  uint32 len,__reg("d1")  uint16 s1,__reg("d2")  uint16 s2) {
}

// useful for debugging
void waitclick() {
#define CIAAPRA ((volatile uint8*)0xbfe001)
  // bfe001 http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node012E.html
  while ((*CIAAPRA & (1<<6))) {
    // wait for left mouse button pressed
  }
  while (!(*CIAAPRA & (1<<6))) {
    // wait for left mouse button released
  }
}

void pan(__reg("a0") struct RTGBoard* b,__reg("a1") uint8* mem,__reg("d0")  uint16 w,__reg("d1")  int16 x,__reg("d2")  int16 y,__reg("d7")  uint16 format) {
  MNTVARegs* registers = b->registers;

  uint32 offset = (mem-(b->memory))>>1; // offset divided by 2 = number of words
  uint32 offhi = (offset&0xffff0000)>>16;
  uint32 offlo = offset&0xfc00;
 
  registers->capture_mode = 0; // CHECKME
  b->scratch[SCR_CAPMODE] = 0;

  registers->pan_ptr_hi = offhi;
  registers->pan_ptr_lo = offlo;
}

void set_memory_mode(__reg("a0") struct RTGBoard* b,__reg("d7")  uint16 format) {
}
void set_read_plane(__reg("a0") struct RTGBoard* b,__reg("d0")  uint8 p) {
}
void set_write_mask(__reg("a0") struct RTGBoard* b,__reg("d0")  uint8 m) {
}
void set_clear_mask(__reg("a0") struct RTGBoard* b,__reg("d0")  uint8 m) {
}
void vsync_wait(__reg("a0") struct RTGBoard* b) {
  MNTVARegs* registers = b->registers;
  while (!registers->vsync) {
  }
}
int is_vsynced(__reg("a0") struct RTGBoard* b,__reg("d0")  uint8 p) {
  MNTVARegs* registers = b->registers;
  if (registers->vsync) return -1;
  return 0;
}
void set_clock(__reg("a0") struct RTGBoard* b) {
}

void set_palette(__reg("a0") struct RTGBoard* b,__reg("d0")  uint16 idx,__reg("d1")  uint16 len) {
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
  uint16 pitch = w;

  if (colormode == MNTVA_COLOR_1BIT) {
    // monochrome, 16 pixels per word
    pitch = w>>3;
  } else if (colormode == MNTVA_COLOR_15BIT) {
    pitch = w<<1;
  } else {
    pitch = w<<colormode;
  }
  return pitch;
}

uint16 rtg_to_mnt_colormode(uint16 format) {
  if (format==RTG_COLOR_FORMAT_CLUT) {
    // format == 1
    return MNTVA_COLOR_8BIT;
  } else if (format==9 || format==8) {
    return MNTVA_COLOR_32BIT;
  } else if (format==0) {
    return MNTVA_COLOR_1BIT;
  } else if (format==0xb || format==0xd || format==5) {
    return MNTVA_COLOR_15BIT;
  }
  // format == 10
  return MNTVA_COLOR_16BIT565;
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

uint16 get_pitch(__reg("a0") struct RTGBoard* b,__reg("d0")  uint16 width,__reg("d7")  uint16 format) {
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
  uint16 pitch = calc_pitch_bytes(w, colormode)>>1; // convert to words
  uint16 pitch_shift = pitch_to_shift(pitch);
  registers->row_pitch = pitch;
  registers->row_pitch_shift = pitch_shift;
}

void init_mode(__reg("a0") struct RTGBoard* b,__reg("a1")  struct ModeInfo* m,__reg("d0")  int16 border) {
  MNTVARegs* registers = b->registers;
  uint16 scale = 0;
  uint16 w;
  uint16 h;
  uint16 colormode;

  b->mode_info = m;
  b->border = border;

  if (m->width<320 || m->height<200) return;

  vsync_wait(b);

  //KPrintF("init_mode cf:\n");
  //KPrintF("%lx\n",b->color_format);

  colormode = rtg_to_mnt_colormode(b->color_format);

  registers->safe_x2 = 0x1e0;
  
  if (colormode == MNTVA_COLOR_32BIT && m->width>=1024) {
    registers->safe_x2 = 0x180;
    registers->fetch_preroll = 0x180;
  } else if (colormode == MNTVA_COLOR_16BIT565 && m->width==1280 || colormode == MNTVA_COLOR_15BIT && m->width==1280) {
    registers->safe_x2 = 0x1d0;
    registers->fetch_preroll = 0x1d0;
  } else if (colormode == MNTVA_COLOR_8BIT && m->width==800) {
    registers->safe_x2 = 0x1f0;
    registers->fetch_preroll = 0x1f0;
  } else {
    registers->fetch_preroll = 0x1e0;
  }

  // FIXME
  if (colormode == MNTVA_COLOR_32BIT) {
    registers->ram_fetch_delay2_max = 0xa;
  } else {
    registers->ram_fetch_delay2_max = 0x17;
  }
  
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

  init_modeline(registers, w, h);
  init_mode_pitch(registers, w, colormode);

  registers->colormode = colormode;

  registers->scalemode = (scale<<2) | scale; // vscale|hscale
  registers->screen_w = w;
  registers->screen_h = h;

  if (colormode==MNTVA_COLOR_32BIT) {
    // for 32bit color, screenw is 2*hrez (fetch double the data)
    registers->line_w = 4+(w<<1);
  } else if (colormode==MNTVA_COLOR_8BIT) {
    registers->line_w = w>>1; // fetch half the data per line
  }

  // reset clock again to clean up any glitches
  init_modeline(registers, w, h);
}

uint32 is_bitmap_compatible(__reg("a0") struct RTGBoard* b,__reg("d7")  uint16 format) {
  return 0xffffffff;
}

uint32 map_address(__reg("a0") struct RTGBoard* b,__reg("a1")  uint32 addr) {
  if (addr>(uint32)b->memory && addr < (((uint32)b->memory) + b->memory_size)) {
    addr=addr&0xfffff000;
  }
  return addr; // direct mapping
}

uint32 get_pixelclock_index(__reg("a0") struct RTGBoard* b,__reg("a1")  struct ModeInfo* mode,__reg("d0")  int32 clock,__reg("d7")  uint16 format) {
  mode->pixel_clock_hz = CLOCK_HZ;
  mode->clock = 0;
  mode->clock_div = 1;
  return 0;
}

uint32 get_pixelclock_hz(__reg("a0") struct RTGBoard* b,__reg("a1")  struct ModeInfo* mode,__reg("d0")  int32 clock,__reg("d7")  uint16 format) {
  return CLOCK_HZ;
}

uint32 monitor_switch(__reg("a0") struct RTGBoard* b,__reg("d0")  uint16 state) {
  MNTVARegs* registers = b->registers;
  
  if (state==0 && CX_ENABLED) {
    // capture amiga video to 16bit
    registers->pan_ptr_hi = 0xf8; // capture at the end of video memory
    registers->pan_ptr_lo = 0;

    //registers->safe_x1 = 0;
    //registers->safe_x2 = 0x220;
    //registers->fetch_preroll = 1;
    //registers->margin_x = 10;

    init_modeline(registers, registers->capture_default_screen_w, registers->capture_default_screen_h);
    init_mode_pitch(registers, registers->capture_default_screen_w, MNTVA_COLOR_16BIT565);
    registers->screen_w = registers->capture_default_screen_w; // default: 640
    registers->screen_h = registers->capture_default_screen_h; // default: 480

    registers->colormode = MNTVA_COLOR_16BIT565;
    registers->scalemode = 0; //4; // scalemode x1:1, y2:1
    
    registers->ram_fetch_delay2_max = 0;

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

void rect_fill(__reg("a0") struct RTGBoard* b,__reg("a1")  struct RenderInfo* r,__reg("d0")  uint16 x,__reg("d1")  uint16 y,__reg("d2")  uint16 w,__reg("d3")  uint16 h,__reg("d4")  uint32 color) {
  uint16 i=0;
  uint8* ptr;
  uint8 color8;
  uint16 pitch = 1024;
  MNTVARegs* registers = b->registers;
  uint8* gfxmem = (uint8*)b->memory;
  uint32 color_format = b->color_format;
  uint32 offset = 0;
  
  blitter_wait(b);
  
  // no blitting in capture mode
  if (b->scratch[SCR_CAPMODE]==1) return;
  
  if (r) {
    offset = ((r->memory-(b->memory)) + y * r->pitch)>>1;
    registers->blitter_src_hi = (offset&0xffff0000)>>16;
    registers->blitter_src_lo = offset&0xffff;
    pitch = r->pitch;
    gfxmem = (uint8*)r->memory;
    color_format = r->color_format;
  } else {
    return;
  }

  registers->blitter_row_pitch = pitch>>1;

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

    x>>=1;
    w>>=1;
    if (w==0) return;
    w--;
    h--;
  } else if (color_format==9 || color_format==8) {
    // true color
    x<<=1;
    w<<=1;
    h--;
    w--;
    registers->blitter_rgb16 = color>>16;
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

void copy_column(uint8* gfxmem,uint32 pitch,uint16 x,uint16 y,uint16 dx,uint16 dy,uint16 h,uint16 col) {
  uint8* ptr_src, *ptr_dst;
  uint16 i;
  if (dy>y) {
    ptr_dst = gfxmem+(dy+h-1)*pitch+dx+col;
    ptr_src = gfxmem+( y+h-1)*pitch+ x+col;
    for (i=0;i<h;i++) {
      *ptr_dst=*ptr_src;
      ptr_dst-=pitch;
      ptr_src-=pitch;
    }
  } else {
    ptr_dst = gfxmem+dy*pitch+dx+col;
    ptr_src = gfxmem+ y*pitch+ x+col;
    for (i=0;i<h;i++) {
      *ptr_dst=*ptr_src;
      ptr_dst+=pitch;
      ptr_src+=pitch;
    }
  }
}

void rect_copy(__reg("a0") struct RTGBoard* b,__reg("a1")  struct RenderInfo* r,__reg("d0")  uint16 x,__reg("d1")  uint16 y,__reg("d2")  uint16 dx,__reg("d3")  uint16 dy,__reg("d4")  uint16 w,__reg("d5")  uint16 h,__reg("d6")  uint8 m,__reg("d7")  uint16 format) {
  MNTVARegs* registers = b->registers;
  uint16 pitch = 1024;
  uint32 color_format = b->color_format;
  uint8* gfxmem = (uint8*)b->memory;
  uint32 offset = 0, y1, y3;
  uint32 i;
  uint8 copy_col_later = 0, reverse = 0;
  uint16 cc_dx, cc_x, cc_dy, cc_y, cc_w, cc_h, cc_col;

  blitter_wait(b);

  // no blitting in capture mode
  if (b->scratch[SCR_CAPMODE]==1) return;

  if (r) {
    pitch = r->pitch;
    color_format = r->color_format;
    gfxmem = (uint8*)r->memory;
  }

  registers->blitter_row_pitch = pitch>>1;
  if (w<4 || h<2) {
    b->fn_rect_copy_fallback(b,r,x,y,dx,dy,w,h,m,format);
    return;
  }

  if (color_format==RTG_COLOR_FORMAT_CLUT) {
    if ((dx&1)!=(x&1)) {
      // can only scroll odd/odd or even/even in x direction
      b->fn_rect_copy_fallback(b,r,x,y,dx,dy,w,h,m,format);
      return;
    }

    if (dx>=x) {
      reverse = 1;
    }
    
    cc_x=x; cc_y=y; cc_dx=dx; cc_dy=dy; cc_w=w; cc_h=h;
    if ((x&1)==0) {
      if ((x+w-1)&1) {
        // x even, x2 odd = nothing special
      } else {
        // x even, x2 odd
        if (reverse) {
          copy_column(gfxmem,pitch,x,y,dx,dy,h,w-1);
        } else {
          copy_col_later=1;
          cc_col=w-1;
        }
        w--;
      }
    } else {
      if ((x+w-1)&1) {
        // x odd, x2 odd
        if (reverse) {
          copy_col_later=1;
          cc_col=0;
        } else {
          copy_column(gfxmem,pitch,x,y,dx,dy,h,0);
        }
        x++;
        dx++;
        w--;
      } else {
        // x odd, x2 even
        if (reverse) {
          copy_column(gfxmem,pitch,x,y,dx,dy,h,w-1);
          copy_col_later=1;
          cc_col=0;
        } else {
          copy_column(gfxmem,pitch,x,y,dx,dy,h,0);
          copy_col_later=1;
          cc_col=w-1;
        }
        x++;
        dx++;
        w-=2;
      }
    }

    dx>>=1;
    x>>=1;
    w>>=1;
    if (w<1) return; // FIXME fallback threshold
    w--;
    h--;
  } else if (color_format==9 || color_format==8) {
    // 32 bit
    x*=2;
    dx*=2;
    w*=2;
    w--;
    h--;
  } else {
    // 16 bit
    w--;
    h--;
  }

  if (dy<y) {
    y1 = dy;
    y3 = y;
    registers->blitter_y1 = dy;
    registers->blitter_y2 = dy+h;
    registers->blitter_y3 = y;
    registers->blitter_y4 = y+h;    
  } else {
    y1 = dy+h;
    y3 = y+h;
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

  if (r) {
    offset = ((r->memory-(b->memory)) + y1 * r->pitch)>>1;
    registers->blitter_src_hi = (offset&0xffff0000)>>16;
    registers->blitter_src_lo = offset&0xffff;
    offset = ((r->memory-(b->memory)) + y3 * r->pitch)>>1;
    registers->blitter_dst_hi = (offset&0xffff0000)>>16;
    registers->blitter_dst_lo = offset&0xffff;
  } else {
    return;
  }

  registers->blitter_enable = 2;
  blitter_wait(b);

  // 8 bit odd column post processing
  if (copy_col_later) {
    copy_column(gfxmem,pitch,cc_x,cc_y,cc_dx,cc_dy,cc_h,cc_col);
  }
}

/*void rect_p2c(__reg("a0") struct RTGBoard* b,__reg("a1")  struct BitMap* bm,__reg("a2")  struct RenderInfo* r,__reg("d0")  uint16 x,__reg("d1")  uint16 y,__reg("d2")  uint16 dx,__reg("d3")  uint16 dy,__reg("d4")  uint16 w,__reg("d5")  uint16 h,__reg("d6")  uint8 minterm,__reg("d7")  uint8 mask) {
  serp1("P2C  mask $00000000  ",(uint32)mask);
  serp1("term $00000000  ",(uint32)minterm);
  serp1("P2C  x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("dx   $00000000  ",(uint32)dx);
  serp1("dy   $00000000  ",(uint32)dy);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}

void rect_template(__reg("a0") struct RTGBoard* b,__reg("a1")  struct RenderInfo* r,__reg("a2")  struct Template* tp,__reg("d0")  uint16 x,__reg("d1")  uint16 y,__reg("d2")  uint16 w,__reg("d3")  uint16 h,__reg("d4")  uint8 mask,__reg("d7")  uint32 format) {
  serp1("TMPL mask $00000000  ",(uint32)mask);
  serp1("frmt $00000000  ",(uint32)format);
  serp1("TMPL x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}

void rect_pattern(__reg("a0") struct RTGBoard* b,__reg("a1")  struct RenderInfo* r,__reg("a2")  struct Pattern* pat,__reg("d0")  uint16 x,__reg("d1")  uint16 y,__reg("d2")  uint16 w,__reg("d3")  uint16 h,__reg("d4")  uint8 mask,__reg("d7")  uint32 format) {
  serp1("PTTN mask $00000000  ",(uint32)mask);
  serp1("frmt $00000000  ",(uint32)format);
  serp1("PTTN x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}

void rect_copy_nomask(__reg("a0") struct RTGBoard* b,__reg("a1")  struct RenderInfo* sr,__reg("a2")  struct RenderInfo* dr,__reg("d0")  uint16 x,__reg("d1")  uint16 y,__reg("d2")  uint16 dx,__reg("d3")  uint16 dy,__reg("d4")  uint16 w,__reg("d5")  uint16 h,__reg("d6")  uint8 opcode,__reg("d7")  uint32 format) {
  serp1("COPC code $00000000  ",(uint32)opcode);
  serp1("frmt $00000000  ",(uint32)format);
  serp1("COPC x    $00000000  ",(uint32)x);
  serp1("y    $00000000  ",(uint32)y);
  serp1("dx   $00000000  ",(uint32)dx);
  serp1("dy   $00000000  ",(uint32)dy);
  serp1("w    $00000000  ",(uint32)w);
  serp1("h    $00000000\r\n",(uint32)h);
}*/

void blitter_wait(__reg("a0") struct RTGBoard* b) {
  volatile uint16 blitter_busy = 0;
  MNTVARegs* registers = b->registers;
  do {
    blitter_busy = registers->blitter_enable;
  } while(blitter_busy!=0);
}

// sprites are currently disabled

/*void sprite_setup(__reg("a0") struct RTGBoard* b,__reg("d0")  uint32 enable) {
}

void sprite_xy(__reg("a0") struct RTGBoard* b) {
  uint8* registers = (uint8*)b->registers;
  uint16 x = b->cursor_x;
  uint16 y = b->cursor_y;

  *((volatile uint16*)(registers+0x40)) = x;
  *((volatile uint16*)(registers+0x42)) = y;
  *((volatile uint16*)(registers+0x44)) = x+(b->cursor_w)-1;
  *((volatile uint16*)(registers+0x46)) = y+(b->cursor_h)-1;
}

void sprite_bitmap(__reg("a0") struct RTGBoard* b) {
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

void sprite_colors(__reg("a0") struct RTGBoard* b,__reg("d0")  uint8 idx,__reg("d1") 
  uint8 red,__reg("d2")  uint8 green,__reg("d3")  uint8 blue) {

  uint8* registers = (uint8*)b->registers;
  //debug("%x %x %x %x",idx,red,green,blue);

  if (idx==0) idx=1;
  else if (idx==1) idx=0;

  *((volatile uint16*)(registers+0x922+2*idx))=blue;
  *((volatile uint16*)(registers+0x912+2*idx))=green;
  *((volatile uint16*)(registers+0x902+2*idx))=red;
}*/
