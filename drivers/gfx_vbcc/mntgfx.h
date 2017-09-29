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

#include <proto/expansion.h>
#include <exec/libraries.h>

#define VERSION  1
#define REVISION 72

#define CLOCK_HZ 75000000

#include "rtg.h"

/* library functions -------------------- */

struct MNTGFXBase {
  struct Library libNode;
  BPTR segList;
  struct ExecBase* sysBase;
  struct ExpansionBase* expansionBase;
};

int FindCard(__reg("a0") struct RTGBoard* b);
int InitCard(__reg("a0") struct RTGBoard* b);

/* rtg functions ------------------------ */

void nop();

void init_dac(__reg("a0") struct RTGBoard* b, __reg("d7") uint16 format);
uint32 enable_display(__reg("a0") struct RTGBoard* b, __reg("d0") uint16 enabled);
void pan(__reg("a0") struct RTGBoard* b,__reg("a1") uint8* mem,__reg("d0") uint16 w,__reg("d1") int16 x,__reg("d2") int16 y,__reg("d7") uint16 format);
void set_memory_mode(__reg("a0") struct RTGBoard* b,__reg("d7") uint16 format);
void set_read_plane(__reg("a0") struct RTGBoard* b,__reg("d0") uint8 p);
void set_write_mask(__reg("a0") struct RTGBoard* b,__reg("d0") uint8 m);
void set_clear_mask(__reg("a0") struct RTGBoard* b,__reg("d0") uint8 m);
void vsync_wait(__reg("a0") struct RTGBoard* b);
int is_vsynced(__reg("a0") struct RTGBoard* b,__reg("d0") uint8 p);
void set_clock(__reg("a0") struct RTGBoard* b);
void set_palette(__reg("a0") struct RTGBoard* b,__reg("d0") uint16 idx,__reg("d1") uint16 len);
void init_mode(__reg("a0") struct RTGBoard* b,__reg("a1") struct ModeInfo* m,__reg("d0") int16 border);
uint32 is_bitmap_compatible(__reg("a0") struct RTGBoard* b,__reg("d7") uint16 format);
uint16 get_pitch(__reg("a0") struct RTGBoard* b,__reg("d0") uint16 width,__reg("d7") uint16 format);
uint32 map_address(__reg("a0") struct RTGBoard* b,__reg("a1") uint32 addr);
uint32 get_pixelclock_index(__reg("a0") struct RTGBoard* b,__reg("a1") struct ModeInfo* mode,__reg("d0") int32 clock,__reg("d7") uint16 format);
uint32 get_pixelclock_hz(__reg("a0") struct RTGBoard* b,__reg("a1") struct ModeInfo* mode,__reg("d0") int32 clock,__reg("d7") uint16 format);
uint32 monitor_switch(__reg("a0") struct RTGBoard* b,__reg("d0") uint16 state);
void rect_p2c(__reg("a0") struct RTGBoard* b,__reg("a1") struct BitMap* bm,__reg("a2") struct RenderInfo* r,__reg("d0") uint16 x,__reg("d1") uint16 y,__reg("d2") uint16 dx,__reg("d3") uint16 dy,__reg("d4") uint16 w,__reg("d5") uint16 h,__reg("d6") uint8 minterm,__reg("d7") uint8 mask);
void rect_fill(__reg("a0") struct RTGBoard* b,__reg("a1") struct RenderInfo* r,__reg("d0") uint16 x,__reg("d1") uint16 y,__reg("d2") uint16 w,__reg("d3") uint16 h,__reg("d4") uint32 color);
void rect_copy(__reg("a0") struct RTGBoard* b,__reg("a1") struct RenderInfo* r,__reg("d0") uint16 x,__reg("d1") uint16 y,__reg("d2") uint16 dx,__reg("d3") uint16 dy,__reg("d4") uint16 w,__reg("d5") uint16 h,__reg("d6") uint8 m,__reg("d7") uint16 format);
void rect_template(__reg("a0") struct RTGBoard* b,__reg("a1") struct RenderInfo* r,__reg("a2") struct Template* tp,__reg("d0") uint16 x,__reg("d1") uint16 y,__reg("d2") uint16 w,__reg("d3") uint16 h,__reg("d4") uint8 mask,__reg("d7") uint32 format);
void rect_pattern(__reg("a0") struct RTGBoard* b,__reg("a1") struct RenderInfo* r,__reg("a2") struct Pattern* pat,__reg("d0") uint16 x,__reg("d1") uint16 y,__reg("d2") uint16 w,__reg("d3") uint16 h,__reg("d4") uint8 mask,__reg("d7") uint32 format);
void rect_copy_nomask(__reg("a0") struct RTGBoard* b,__reg("a1") struct RenderInfo* sr,__reg("a2") struct RenderInfo* dr,__reg("d0") uint16 x,__reg("d1") uint16 y,__reg("d2") uint16 dx,__reg("d3") uint16 dy,__reg("d4") uint16 w,__reg("d5") uint16 h,__reg("d6") uint8 opcode,__reg("d7") uint32 format);
void blitter_wait(__reg("a0") struct RTGBoard* b);

void sprite_setup(__reg("a0") struct RTGBoard* b,__reg("d0") uint32 enable);
void sprite_xy(__reg("a0") struct RTGBoard* b);
void sprite_bitmap(__reg("a0") struct RTGBoard* b);
void sprite_colors(__reg("a0") struct RTGBoard* b,__reg("d0") uint8 idx,__reg("d1") 
          uint8 red,__reg("d2") uint8 green,__reg("d3") uint8 blue);
