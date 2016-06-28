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

#define SD_RESET ((volatile uint16*)(SD_BASE+0x60))
#define SD_READ ((volatile uint16*)(SD_BASE+0x62))
#define SD_WRITE ((volatile uint16*)(SD_BASE+0x64))
#define SD_ADDR ((volatile uint32*)(SD_BASE+0x68))
#define SD_DATA_IN ((volatile uint16*)(SD_BASE+0x6c))
#define SD_DATA_OUT ((volatile uint8*)(SD_BASE+0x6e))
#define SD_ERR ((volatile uint16*)(SD_BASE+0x70))
#define SD_BUSY ((volatile uint8*)(SD_BASE+0x60))
#define SD_HANDSHAKE ((volatile uint16*)(SD_BASE+0x66))

uint16 sdcmd_read_blocks(void* cmd, uint32 block, uint8* data, uint32 len) {
  uint32 i=0;
  uint32 x=0;
  uint32 offset=0;
  uint8 rbyte=0;
  //uint32 checksum=0;
  //return 0;

  //kprintf("SD read blocks: %ld (%ld)\n",block,len);

  *SD_WRITE = 0;
  *SD_READ = 0;
  *SD_HANDSHAKE = 0x00;
  
  for (i=0; i<len; i++) {
    *SD_ADDR = block+i;
    *SD_HANDSHAKE = 0x00;
    *SD_READ = 0xffff;
    offset = i<<9;
    
    while (!*SD_BUSY) {};

    //checksum=0;
    for (x=0; x<512; x++) {
      while (!*SD_HANDSHAKE) {};
      *SD_READ = 0;
      rbyte = *SD_DATA_OUT;
      data[offset+x] = rbyte;
      //checksum+=rbyte;
      *SD_HANDSHAKE = 0xffff;
      while (*SD_HANDSHAKE) {};
      *SD_HANDSHAKE = 0x00;
    }
    //kprintf("BLK %ld: %lx\n",block+i,checksum);
  }
  *SD_READ = 0;
  return *SD_ERR;
}

uint16 sdcmd_write_blocks(void* cmd, uint32 block, uint8* data, uint32 len) {
  uint32 i=0;
  uint32 x=0;
  uint32 j=len;
  uint32 base = block;
  //return 0;
  
  //kprintf("SD write blocks: %ld (%ld)\n",block,len);
  
  *SD_WRITE = 0;
  *SD_READ = 0;
  *SD_HANDSHAKE = 0x00;
  
  for (i=0; i<j; i++) {
    *SD_ADDR = base+i;
    *SD_WRITE = 0xffff;

    while (!*SD_BUSY) {};

    for (x=0; x<512; x++) {
      while (!*SD_HANDSHAKE) {};
      *SD_WRITE = 0;
      *SD_DATA_IN = data[(i<<9)+x]<<8;
    
      *SD_HANDSHAKE = 0xffff;
      while (*SD_HANDSHAKE) {};
      *SD_HANDSHAKE = 0x00;
    }
  }
  *SD_WRITE = 0;
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
  unsigned int i=0;
  unsigned int block=0;
  uint8* test = (uint8*)malloc(512);

  if (argc>1) {
    if (argv[1][0]=='r') {
      printf("resetting\n");
      *SD_READ = 0x00;
      *SD_WRITE = 0x00;
      *SD_ADDR = 0x00;
      *SD_RESET = 0xffff;
      *SD_HANDSHAKE = 0xffff;
      *SD_HANDSHAKE = 0x00;
      for (i=0;i<4;i++) {
        printf("%d\n",i);
      }
      *SD_RESET = 0;
      return 0;
    }
    
    block=atoi(argv[1]);
  }
  
  *SD_WRITE = 0x00;
  *SD_READ = 0x00;
  *SD_HANDSHAKE = 0x00;

  printf("busy: %d\n",*SD_BUSY);

  if (argc>2) {
    printf("write mode to block %d!\n",2);

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
