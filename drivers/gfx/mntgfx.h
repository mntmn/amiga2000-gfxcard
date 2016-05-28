
#include <exec/errors.h>
#include <exec/memory.h>
#include <exec/lists.h>
#include <exec/alerts.h>

#include <libraries/expansion.h>

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
void set_read_plane(register struct RTGBoard* b asm("a0"), uint8 p asm("d0"));
void set_write_mask(register struct RTGBoard* b asm("a0"), uint8 m asm("d0"));
void set_clear_mask(register struct RTGBoard* b asm("a0"), uint8 m asm("d0"));
void vsync_wait(register struct RTGBoard* b asm("a0"));
int is_vsynced(register struct RTGBoard* b asm("a0"));
void set_clock(register struct RTGBoard* b asm("a0"));
void set_palette(register struct RTGBoard* b asm("a0"),uint16 idx asm("d0"),uint16 len asm("d1"));
void init_mode(register struct RTGBoard* b asm("a0"), struct ModeInfo* m asm("a1"), int16 border asm("d0"));
uint32 is_bitmap_compatible(register struct RTGBoard* b asm("a0"), uint16 format asm("d7"));
uint16 get_pitch(register struct RTGBoard* b asm("a0"), uint16 width asm("d0"), uint16 format asm("d7"));
uint32 map_address(register struct RTGBoard* b asm("a0"), uint32 addr asm("a1"));
uint32 get_pixelclock_index(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7"));
uint32 get_pixelclock_hz(register struct RTGBoard* b asm("a0"), struct ModeInfo* mode asm("a1"), int32 clock asm("d0"), uint16 format asm("d7"));
uint32 monitor_switch(register struct RTGBoard* b asm("a0"), uint16 state asm("d0"));
void rect_fill(register struct RTGBoard* b asm("a0"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 w asm("d2"), uint16 h asm("d3"), uint32 color asm("d4"));
void rect_copy(register struct RTGBoard* b asm("a0"), register void* r asm("a1"), uint16 x asm("d0"), uint16 y asm("d1"), uint16 dx asm("d2"), uint16 dy asm("d3"), uint16 w asm("d4"), uint16 h asm("d5"), uint8 m asm("d6"), uint16 format asm("d7"));
void blitter_wait(register struct RTGBoard* b asm("a0"));
