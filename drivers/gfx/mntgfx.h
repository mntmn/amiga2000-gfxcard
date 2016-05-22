
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

int nop();
uint32 get_pitch();
uint32 map_address(struct RTGBoard* b, uint32 addr);
uint32 get_pixelclock_index(struct RTGBoard* b);
uint32 get_pixelclock(struct RTGBoard* b);
int set_clock();
void enable_display();
int init_dac();
int pan();
uint32 monitor_switch(struct RTGBoard* b);
uint32 init_chip(struct RTGBoard* b, struct ModeInfo* m, int16 border);
