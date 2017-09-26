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

#include <exec/errors.h>
#include <exec/memory.h>
#include <exec/lists.h>
#include <exec/alerts.h>

#include <libraries/expansion.h>
#include <libraries/configvars.h>

const char LibName[]="mntgfx.card";
const char LibIdString[]="mntgfx.card 1.0";

const UWORD LibVersion=1;
const UWORD LibRevision=0;

#define CLOCK_HZ 75000000

#include "stabs.h"
#include "rtg.h"

void nop();

void init_dac(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7"));
uint32 enable_display(register struct RTGBoard* b asm("a0"), register uint16 enabled asm("d0"));
void pan(register struct RTGBoard* b asm("a0"), register void* mem asm("a1"), register uint16 w asm("d0"), register int16 x asm("d1"), register int16 y asm("d2"), register uint16 format asm("d7"));
void set_memory_mode(register struct RTGBoard* b asm("a0"), register uint16 format asm("d7"));
void set_read_plane(register struct RTGBoard* b asm("a0"), register uint8 p asm("d0"));
void set_write_mask(register struct RTGBoard* b asm("a0"), register uint8 m asm("d0"));
void set_clear_mask(register struct RTGBoard* b asm("a0"), register uint8 m asm("d0"));
void vsync_wait(register struct RTGBoard* b asm("a0"));
int is_vsynced(register struct RTGBoard* b asm("a0"), register uint8 p asm("d0"));
void set_clock(register struct RTGBoard* b asm("a0"));
void set_palette(register struct RTGBoard* b asm("a0"), uint16 idx asm("d0"),uint16 len asm("d1"));
void init_mode(register struct RTGBoard* b asm("a0"), struct ModeInfo* m asm("a1"), int16 border asm("d0"));
uint32 is_bitmap_compatible(register struct RTGBoard* b asm("a0"), uint16 format asm("d7"));
uint16 get_pitch(register struct RTGBoard* b asm("a0"), uint16 width asm("d0"), uint16 format asm("d7"));
uint32 map_address(register struct RTGBoard* b asm("a0"), uint32 addr asm("a1"));
uint32 get_pixelclock_index(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7"));
uint32 get_pixelclock_hz(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7"));
uint32 monitor_switch(register struct RTGBoard* b asm("a0"), uint16 state asm("d0"));
void rect_p2c(register struct RTGBoard* b asm("a0"), struct BitMap* bm asm("a1"), struct RenderInfo* r asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 minterm asm("d6"), uint8 mask asm("d7"));
void rect_fill(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint32 color asm("d4"));
void rect_copy(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 m asm("d6"), uint16 format asm("d7"));
void rect_template(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), struct Template* tp asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint8 mask asm("d4"), uint32 format asm("d7"));
void rect_pattern(register struct RTGBoard* b asm("a0"), struct RenderInfo* r asm("a1"), struct Pattern* pat asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint8 mask asm("d4"), uint32 format asm("d7"));
void rect_copy_nomask(register struct RTGBoard* b asm("a0"), struct RenderInfo* sr asm("a1"), struct RenderInfo* dr asm("a2"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 opcode asm("d6"), uint32 format asm("d7"));
void blitter_wait(register struct RTGBoard* b asm("a0"));

void sprite_setup(register struct RTGBoard* b asm("a0"), register uint32 enable asm("d0"));
void sprite_xy(register struct RTGBoard* b asm("a0"));
void sprite_bitmap(register struct RTGBoard* b asm("a0"));
void sprite_colors(register struct RTGBoard* b asm("a0"), register uint8 idx asm("d0"),
                   register uint8 red asm("d1"), register uint8 green asm("d2"), register uint8 blue asm("d3"));
