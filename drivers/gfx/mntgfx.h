
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
uint16 get_pitch(struct RTGBoard* b, uint16 width, uint16 format);
uint32 map_address(struct RTGBoard* b, uint32 addr);
uint32 get_pixelclock_index(struct RTGBoard* b, struct ModeInfo* mode, int32 clock, uint16 format);
uint32 get_pixelclock_hz(struct RTGBoard* b, struct ModeInfo* mode, int32 clock, uint16 format);
void rect_fill(struct RTGBoard* b, uint16 x, uint16 y, uint16 w, uint16 h, uint32 color);
void blitter_wait(struct RTGBoard* b);
uint32 enable_display(struct RTGBoard* b, uint16 enabled);
void init_dac(struct RTGBoard* b, uint16 format);
void pan(struct RTGBoard* b, void* mem, uint16 w, int16 x, int16 y, uint16 format);
uint32 monitor_switch(struct RTGBoard* b, uint16 state);
void init_mode(struct RTGBoard* b, struct ModeInfo* m, int16 border);

void set_memory_mode(register struct RTGBoard* b asm("a0"), uint16 format);
void set_read_plane(struct RTGBoard* b, uint8 p);
void set_write_mask(struct RTGBoard* b, uint8 m);
void set_clear_mask(struct RTGBoard* b, uint8 m);
void vsync_wait(struct RTGBoard* b);
void set_clock(struct RTGBoard* b);
void set_palette(struct RTGBoard* b,uint16 idx,uint16 len);

uint32 is_bitmap_compatible(struct RTGBoard* b, uint16 format);
