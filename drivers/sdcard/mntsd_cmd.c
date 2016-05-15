#include <exec/resident.h>
#include <exec/errors.h>
#include <exec/memory.h>
#include <exec/lists.h>
#include <exec/alerts.h>
#include <exec/tasks.h>
#include <exec/io.h>

#include <libraries/expansion.h>

#include <devices/trackdisk.h>
#include <devices/timer.h>
#include <devices/scsidisk.h>

#include <dos/filehandler.h>

#include <proto/exec.h>
#include <proto/disk.h>
#include <proto/expansion.h>

#include "mntsd_cmd.h"

#define SD_RESET ((uint8*)(SD_BASE+0x30))
#define SD_READ ((uint8*)(SD_BASE+0x32))
#define SD_WRITE ((uint8*)(SD_BASE+0x34))
#define SD_ADDR ((uint32*)(SD_BASE+0x38))
#define SD_DATA_IN ((uint8*)(SD_BASE+0x3c))
#define SD_DATA_OUT ((uint8*)(SD_BASE+0x3e))
#define SD_ERR ((uint16*)(SD_BASE+0x40))
#define SD_BUSY ((uint8*)(SD_BASE+0x30))
#define SD_HANDSHAKE ((uint8*)(SD_BASE+0x36))

uint16 sdcmd_read_blocks(void* cmd, uint32 block, uint8* data, uint32 len) {
  uint32 i=0;
  uint32 x=0;
  uint32 j=len;
  uint32 base = block;
  //return 0;

  kprintf("SD read blocks: %ld (%ld)\n",block,len);

  *SD_WRITE = 0;
  
  for (i=0; i<j; i++) {
    *SD_ADDR = base+i;
    *SD_READ = 0xff;

    while (!*SD_BUSY) {};
    
    for (x=0; x<512; x++) {
      while (!*SD_HANDSHAKE) {};
      *SD_READ = 0;
      data[(i<<9)+x] = *SD_DATA_OUT;
      *SD_HANDSHAKE = 0xff;
      while (*SD_HANDSHAKE) {};
      *SD_HANDSHAKE = 0x00;
    }
  }
  return *SD_ERR;
}

uint16 sdcmd_write_blocks(void* cmd, uint32 block, uint8* data, uint32 len) {
  uint32 i=0;
  uint32 x=0;
  uint32 j=len;
  uint32 base = block;
  //return 0;
  
  kprintf("SD write blocks: %ld (%ld)\n",block,len);
  
  *SD_READ = 0;
  
  for (i=0; i<j; i++) {
    *SD_ADDR = base+i;
    *SD_WRITE = 0xff;

    while (!*SD_BUSY) {};

    for (x=0; x<512; x++) {
      while (!*SD_HANDSHAKE) {};
      *SD_WRITE = 0;
      *SD_DATA_IN = data[(i<<9)+x];
    
      *SD_HANDSHAKE = 0xff;
      while (*SD_HANDSHAKE) {};
      *SD_HANDSHAKE = 0x00;
    }
  }
  return *SD_ERR;
}

uint16 sdcmd_present(struct sdcmd* cmd) {
  cmd->info.blocks = 1024*1024*2; // 1GB
  cmd->info.block_size = 512;
  return 1;
}

uint16 sdcmd_detect() {
  return 0;
}

/*
int main(int argc, char** argv) {
  int i=0;
  int block=0;
  uint8* test = (uint8*)malloc(512);

  if (argc>1) {
    block=atoi(argv[1]);
  }

  *SD_WRITE = 0x00;
  *SD_READ = 0x00;
  *SD_HANDSHAKE = 0x00;

  if (argc>2) {
    block=2;
    printf("write mode!\n");

    for (i=0; i<512; i++) {
      test[i]=i;
    }
    sdcmd_write_blocks(NULL, block, test, 1);
    
    printf("\n");
  } else {
    
    printf("sd driver read block %d:\n",block);
    sdcmd_read_blocks(NULL, block, test, 1);
    for (i=0; i<512; i++) {
      if (i%32==0) printf("\n");
      printf("%02x",test[i]);
    }
    printf("\n");
  }
  free(test);
}
*/
