/*
 * MNT ZZ9000 Amiga Gfx Card Driver (mntgfx.card)
 * Copyright (C) 2016-2019, Lukas F. Hartmann <lukas@mntmn.com>
 *                          MNT Research GmbH, Berlin
 *                          https://mntmn.com
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
#include "zz9000.h"

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
static const char LibraryID[]   = "$VER: mntgfx.card 3.00 (2019-02-06)\r\n";

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
    KPrintF("failed to open expansion.library!\n");
    return 0;
  }
  
  if ((cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x4)) || (cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x3))) {
    KPrintF("MNT ZZ9000 found.\n");
    b->memory = (uint8*)(cd->cd_BoardAddr)+0x10000;
    b->memory_size = cd->cd_BoardSize-0x10000;
    b->registers = (uint8*)(cd->cd_BoardAddr);
    fwrev = ((uint16*)b->registers)[0];
    
    return 1;
  } else {
    KPrintF("MNT ZZ9000 not found!\n");
    return 0;
  }

  /*uint32_t base = 0x600000;
  b->memory = (uint8*)(base)+0x10000;
  b->memory_size = 0x400000;
  b->registers = (uint8*)0x600000;
  return 1;*/
}

int InitCard(__reg("a0") struct RTGBoard* b) {
  int max;
  struct ExecBase *SysBase = *(struct ExecBase **)4L;

  b->self = MNTGFXBase;
  b->exec = SysBase;
  b->name = "ZZ9000";
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

  uint32 offset = (mem-(b->memory));
  uint32 offhi = (offset&0xffff0000)>>16;
  uint32 offlo = offset&0xfc00;

  registers->pan_ptr_hi = offhi;
  registers->pan_ptr_lo = offlo;
  
  // video control op: vsync
  *(u16*)((uint32)registers+0x1000) = 0;
  *(u16*)((uint32)registers+0x1002) = 1;
  for (int i=0; i<100; i++) {
    *(volatile u16*)((uint32)registers+0x1004) = 5; // OP_VSYNC
  }
  *(u16*)((uint32)registers+0x1002) = 0;
  *(u16*)((uint32)registers+0x1004) = 0; // NOP
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
}
int is_vsynced(__reg("a0") struct RTGBoard* b,__reg("d0")  uint8 p) {
  return -1;
}
void set_clock(__reg("a0") struct RTGBoard* b) {
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

  int hmax,vmax,hstart,hend,vstart,vend;
  
  if (w==1280 && h==720) {
    registers->mode = 0;
    hmax=1980;
    vmax=750;
    hstart=1720;
    hend=1760;
    vstart=725;
    vend=730;
  } else if (w==800) {
    registers->mode = 1;
    hmax=1056;
    vmax=628;
    hstart=840;
    hend=968;
    vstart=601;
    vend=605;
  } else if (w==640) {
    registers->mode = 2;
    // 25.17 640 656 752 800 480 490 492 525
    hmax=800;
    vmax=525;
    hstart=656;
    hend=752;
    vstart=490;
    vend=492;
  } else if (w==1024) {
    registers->mode = 3;
    hmax=1344;
    vmax=806;
    hstart=1048;
    hend=1184;
    vstart=771;
    vend=777;
  } else if (w==1280 && h==1024) {
    // 108.00 1280 1328 1440 1688 1024 1025 1028 1066
    registers->mode = 4;
    hmax=1688;
    vmax=1066;
    hstart=1328;
    hend=1440;
    vstart=1025;
    vend=1028;
  } else if (w==1920 && h==1080) {
    // ModeLine "1920x1080" 148.50 1920 2448 2492 2640 1080 1084 1089 1125 +HSync +VSync
    // 148.35 1920 2008 2052 2200 1080 1084 1089 1125
    registers->mode = 5;
    hmax=2640;
    vmax=1125;
    hstart=2448;
    hend=2492;
    vstart=1084;
    vend=1089;
  }
  
  *(u16*)((uint32)registers+0x1000) = vmax;
  *(u16*)((uint32)registers+0x1002) = hmax;
  *(u16*)((uint32)registers+0x1004) = 6; // OP_MAX
  *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
  *(u16*)((uint32)registers+0x1000) = hstart;
  *(u16*)((uint32)registers+0x1002) = hend;
  *(u16*)((uint32)registers+0x1004) = 7; // OP_HS
  *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
  *(u16*)((uint32)registers+0x1000) = vstart;
  *(u16*)((uint32)registers+0x1002) = vend;
  *(u16*)((uint32)registers+0x1004) = 8; // OP_HS
  *(u16*)((uint32)registers+0x1004) = 0; // NOP
}

void init_mode_pitch(MNTVARegs* registers, uint16 w, uint16 colormode) {
}

void init_mode(__reg("a0") struct RTGBoard* b,__reg("a1")  struct ModeInfo* m,__reg("d0")  int16 border) {
  MNTVARegs* registers = b->registers;
  uint16 scale = 0;
  uint16 w;
  uint16 h;
  uint16 colormode;
  uint16 hdiv=1, vdiv=1;

  b->mode_info = m;
  b->border = border;

  if (m->width<320 || m->height<200) return;

  colormode = rtg_to_mnt_colormode(b->color_format);
  
  if (m->height>=480 || m->width>=640) {
    scale = 0;
    w = m->width;
    h = m->height;
  } else {
    // small doublescan modes are scaled 2x
    // and output as 640x480 wrapped in 800x600 sync
    scale = 3;
    hdiv = 2;
    vdiv = 2;
    
    w = 2*m->width;
    h = 2*m->height;
    if (h<480) h=480;
  }

  if (colormode==0) hdiv*=4;
  if (colormode==1) hdiv*=2;

  //registers->colormode = colormode;
  //registers->scalemode = scale; // vscale|hscale

  registers->hdiv = hdiv;
  registers->vdiv = vdiv;
  
  // video control op: scale
  *(u16*)((uint32)registers+0x1000) = 0;
  *(u16*)((uint32)registers+0x1002) = scale;
  *(u16*)((uint32)registers+0x1004) = 4; // OP_SCALE
  *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
  init_modeline(registers, w, h);
  init_mode_pitch(registers, w, colormode);

  // video control op: dimensions
  *(u16*)((uint32)registers+0x1000) = h;
  *(u16*)((uint32)registers+0x1002) = w;
  *(u16*)((uint32)registers+0x1004) = 2; // OP_DIMENSIONS
  *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
  // video control op: colormode
  *(u16*)((uint32)registers+0x1000) = 0;
  *(u16*)((uint32)registers+0x1002) = colormode;
  *(u16*)((uint32)registers+0x1004) = 1; // OP_COLORMODE
  *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
  // video control op: vsync
  *(u16*)((uint32)registers+0x1000) = 0;
  *(u16*)((uint32)registers+0x1002) = 1;
  for (int i=0; i<100; i++) {
    *(volatile u16*)((uint32)registers+0x1004) = 5; // OP_VSYNC
  }
  *(u16*)((uint32)registers+0x1002) = 0;
  *(u16*)((uint32)registers+0x1004) = 0; // NOP

  
  //registers->scalemode = (scale<<2) | scale; // vscale|hscale
  //registers->screen_w = w;
  //registers->screen_h = h;
}

void set_palette(__reg("a0") struct RTGBoard* b,__reg("d0")  uint16 idx,__reg("d1")  uint16 len) {
  MNTVARegs* registers = b->registers;
  int i;
  int j;
  
  len+=idx;
  for (i=idx, j=idx*3; i<len; i++) {
    u32 ctrldata = ((u32)i<<24)|(((u32)b->palette[j])<<16)|(((u32)b->palette[j+1])<<8)|(u32)b->palette[j+2];
    
    *(u16*)((uint32)registers+0x1000) = ctrldata>>16;
    *(u16*)((uint32)registers+0x1002) = ctrldata&0xffff;
    *(u16*)((uint32)registers+0x1004) = 3; // OP_PALETTE
    *(u16*)((uint32)registers+0x1004) = 0; // NOP
    j+=3;
  }
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
  
  /*if (state==0) {
    // capture amiga video to 16bit
    registers->pan_ptr_hi = 0x1; // FIXME capture to where?
    registers->pan_ptr_lo = 0xc200;

    int w = 640;
    int h = 480;
    int colormode = MNTVA_COLOR_32BIT;
    
    registers->hdiv = 1;
    registers->vdiv = 2;
  
    // video control op: scale
    *(u16*)((uint32)registers+0x1000) = 0;
    *(u16*)((uint32)registers+0x1002) = 2;
    *(u16*)((uint32)registers+0x1004) = 4; // OP_SCALE
    *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
    init_modeline(registers, w, h);
    init_mode_pitch(registers, w, colormode);

    // video control op: dimensions
    *(u16*)((uint32)registers+0x1000) = h;
    *(u16*)((uint32)registers+0x1002) = w;
    *(u16*)((uint32)registers+0x1004) = 2; // OP_DIMENSIONS
    *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
    // video control op: colormode
    *(u16*)((uint32)registers+0x1000) = 0;
    *(u16*)((uint32)registers+0x1002) = colormode;
    *(u16*)((uint32)registers+0x1004) = 1; // OP_COLORMODE
    *(u16*)((uint32)registers+0x1004) = 0; // NOP
  
    // video control op: vsync
    *(u16*)((uint32)registers+0x1000) = 0;
    *(u16*)((uint32)registers+0x1002) = 1;
    for (int i=0; i<100; i++) {
      *(volatile u16*)((uint32)registers+0x1004) = 5; // OP_VSYNC
    }
    *(u16*)((uint32)registers+0x1002) = 0;
    *(u16*)((uint32)registers+0x1004) = 0; // NOP
    
    *(u16*)((uint32)registers+0x1006) = 1; // capture mode
    b->scratch[SCR_CAPMODE] = 1;
  } else {
    // rtg mode
    *(u16*)((uint32)registers+0x1006) = 0; // capture mode
    
    b->scratch[SCR_CAPMODE] = 0;
    //init_mode(b, b->mode_info, b->border);
    }*/
  
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

  if (w<1 || h<1) return;
  
  if (r) {
    offset = (r->memory-(b->memory));
    registers->blitter_dst_hi = (offset&0xffff0000)>>16;
    registers->blitter_dst_lo = offset&0xffff;
    pitch = r->pitch;
    gfxmem = (uint8*)r->memory;
    color_format = r->color_format;
  } else {
    return;
  }

  color_format = rtg_to_mnt_colormode(color_format);

  registers->blitter_rgb_hi = color>>16;
  registers->blitter_rgb_lo = color&0xffff;

  registers->blitter_row_pitch = pitch>>2;
  registers->blitter_colormode = color_format;

  registers->blitter_x1 = x;
  registers->blitter_y1 = y;
  registers->blitter_x2 = x+w-1;
  registers->blitter_y2 = y+h-1;

  registers->blitter_op_fillrect = 1;
}

void rect_copy(__reg("a0") struct RTGBoard* b,__reg("a1")  struct RenderInfo* r,__reg("d0")  uint16 x,__reg("d1")  uint16 y,__reg("d2")  uint16 dx,__reg("d3")  uint16 dy,__reg("d4")  uint16 w,__reg("d5")  uint16 h,__reg("d6")  uint8 m,__reg("d7")  uint16 format) {
  MNTVARegs* registers = b->registers;
  uint16 pitch = 1024;
  uint32 color_format = b->color_format;
  uint8* gfxmem = (uint8*)b->memory;
  uint32 offset = 0, y1, y3;
  
  if (w<1 || h<1) return;
  
  if (r) {
    pitch = r->pitch;
    color_format = r->color_format;
    gfxmem = (uint8*)r->memory;
  } else {
    return;
  }
  
  color_format = rtg_to_mnt_colormode(color_format);

  registers->blitter_y1 = dy;
  registers->blitter_y2 = dy+h-1;
  registers->blitter_y3 = y;
  
  registers->blitter_x1 = dx;
  registers->blitter_x2 = dx+w-1;
  registers->blitter_x3 = x;
  
  registers->blitter_row_pitch = pitch>>2; // 1 long = 4 bytes
  registers->blitter_colormode = color_format;

  offset = (r->memory-(b->memory));
  registers->blitter_src_hi = (offset&0xffff0000)>>16;
  registers->blitter_src_lo = offset&0xffff;
  offset = (r->memory-(b->memory));
  registers->blitter_dst_hi = (offset&0xffff0000)>>16;
  registers->blitter_dst_lo = offset&0xffff;

  registers->blitter_op_copyrect = 2;
}

void blitter_wait(__reg("a0") struct RTGBoard* b) {
}
