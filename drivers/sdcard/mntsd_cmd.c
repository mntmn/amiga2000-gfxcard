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

//#define LOOP_TIMEOUT 5000
#define CRC_RETRIES 3
static uint32 LOOP_TIMEOUT=1000000;

struct MNTSDRegs {
  volatile uint16 busy; // 60 also reset
  volatile uint16 read; // 62
  volatile uint16 write; // 64
  volatile uint16 handshake; // 66
  volatile uint16 addr_hi; // 68
  volatile uint16 addr_lo; // 6a
  volatile uint16 data_in; // 6c
  volatile uint16 data_out; // 6e data in upper byte!
  volatile uint16 err; // 70
};

const uint16 crc_table[256] = {
	0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
	0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
	0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
	0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
	0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
	0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
	0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
	0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
	0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
	0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
	0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
	0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
	0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
	0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
	0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
	0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
	0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
	0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
	0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
	0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
	0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
	0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
	0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
	0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
	0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
	0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
	0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
	0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
	0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
	0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
	0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
	0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0
};

static inline uint16 crc(uint16 crc, uint8 data)
{
  return (crc << 8) ^ crc_table[((crc >> 8) ^ data) & 0xff];
}

void sd_reset(void* regs) {
  uint32 i=0;
  struct MNTSDRegs* registers = (struct MNTSDRegs*)regs;
  registers->read = 0x00;
  registers->write = 0x00;
  registers->addr_hi = 0x00;
  registers->addr_lo = 0x00;
  registers->busy = 0xffff;
  registers->handshake = 0xffff;
  registers->handshake = 0x00;
  for (i=0; i<5000; i++) {
    asm("nop");
  }
  registers->busy = 0;
}

uint16 sdcmd_read_blocks(void* registers, uint32 block, uint8* data, uint32 len) {
  uint32 i=0;
  uint32 x=0;
  uint32 k=0;
  uint32 offset=0;
  uint8 rbyte=0;
  uint32 timer=0;
  uint16 block_crc=0;
  uint16 block_crc_actual=0;
  uint8 retries=0;
  uint16 addrhi;
  int problems=0;
  volatile struct MNTSDRegs* regs = (volatile struct MNTSDRegs*)registers;
  
  //printf("SD read blocks: %ld (%ld)\n",block,len);

  regs->write = 0;
  regs->read = 0;
  regs->handshake = 0x00;
  
  while (regs->busy) {
    timer++;
    if (timer>LOOP_TIMEOUT) {
      //printf("rbusy\n");
      break;
    }
  }
  
  for (i=0; i<len; i++) {
    //retry_loop:
    offset = i<<9;
    timer = 0;
    block_crc = 0;
    problems = 0;

    regs->addr_hi = ((block+i)>>16);
    regs->addr_lo = (block+i)&0xffff;
    regs->handshake = 0x00;
    regs->read = 0xffff;

    do {
      timer++;
      if (timer>LOOP_TIMEOUT) {
        problems++;
        break;
      }
    } while (!regs->busy);
    retries = 0;

    regs->read = 0;
    for (x=0; x<514; x++) {
      timer = 0;
      while (!regs->handshake) {
        timer++;
        if (timer>LOOP_TIMEOUT) {
          //problems++;
          break; // kprintf("h1 %d\n",x);
        }
      }
      rbyte = regs->data_out>>8;
      if (x==512) {
        //block_crc_actual = rbyte<<8;
      } else if (x==513) {
        //block_crc_actual |= rbyte;
      } else {
        data[offset+x] = rbyte;
        //block_crc = crc(block_crc,rbyte); 
      }
      regs->handshake = 0xffff;
      timer = 0;
      while (regs->handshake) {
        timer++;
        if (timer>LOOP_TIMEOUT) {
          //problems++;
          break; // kprintf("h2\n");
        }
      }
      regs->handshake = 0x00;
    }

    /*if (block_crc!=block_crc_actual && retries<CRC_RETRIES) {
      kprintf("BLK %ld CRCex: %x\n",block+i,block_crc);
      kprintf("CRCac: %x\n",block_crc_actual);
      retries++;
      goto retry_loop;
      }*/
    /*if (problems>0) {
      kprintf("BLK %ld timing problems:\n",block+i);
      kprintf("%d\n",problems);
    }*/
  }
  regs->read = 0;
  return regs->err;
}

uint16 sdcmd_write_blocks(void* registers, uint32 block, uint8* data, uint32 len) {
  uint32 i=0;
  uint32 x=0;
  uint32 k=0;
  uint32 timer = 0;
  uint16 block_crc=0;
  uint8 byte;
  uint8 timeout=0;
  uint8 retries=0;
  struct MNTSDRegs* regs = (struct MNTSDRegs*)registers;
  
  //printf("SD write blocks: %ld (%ld)\n",block,len);
  
  for (i=0; i<len; i++) {
    retries=0;
  retry_write:

    timeout=0;
    timer=0;
    
    do {
      timer++;
      if (timer>LOOP_TIMEOUT) {
        timeout|=8;
        break;
      }
    } while (regs->busy);
    if (timeout) {
      kprintf("busy abort blk %d!\n",block+i);
      return;
    }
    
    /*regs->handshake = 0x00;
    regs->write = 0;
    regs->read = 0;*/
    
    block_crc = 0;

    timer=0;
    regs->addr_hi = ((block+i)>>16)&0xffff;
    regs->addr_lo = (block+i)&0xffff;
    regs->write = 0xffff;
    
    for (x=0; x<514; x++) {
      timer=0;
      do {
        timer++;
        if (timer>LOOP_TIMEOUT) {
          timeout|=2;
          break;
        }
      } while (!regs->handshake);
      if (timeout) {
        kprintf("handshake1 abort: %x\n",x);
        return;
      }
      
      if (x==512) {
        regs->data_in = block_crc;
      } else if (x==513) {
        regs->data_in = block_crc<<8;
      } else {
        byte = data[(i<<9)+x];
        regs->data_in = byte<<8;
        block_crc = crc(block_crc,byte); 
      }
      
      regs->handshake = 0xffff;
      
      timer=0;
      do {
        timer++;
        if (timer>LOOP_TIMEOUT) {
          timeout|=4;
          break;
        }
      } while (regs->handshake);
      if (timeout) {
        kprintf("handshake2 abort!\n");
        return;
      }
      
      regs->handshake = 0;
    }
    // block done
    regs->write = 0;

    /*if (timeout>0) {
      //printf("timeout blk %d map %d\n",block+i,timeout);
      if (retries++>2) {
        kprintf("error: giving up!\n");
      }
      else {
        kprintf("RETRY! %lx\n",(block+i));
        sd_reset(registers);    
        goto retry_write;
      }
    }*/
  }
  
  return regs->err;
}

uint16 sdcmd_present(struct sdcmd* cmd) {
  cmd->info.blocks = 1024*1024*4; // 2GB
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

  struct Library* ExpansionBase;
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  struct ConfigDev* cd = NULL;
  struct MNTSDRegs* registers = NULL;
  uint8* test = (uint8*)malloc(512);

  LOOP_TIMEOUT=1000000;

  printf("welcome to MNT VA2000 SD card tester.\n");
  
  if ((ExpansionBase = (struct Library*)OpenLibrary("expansion.library",0L))==NULL) {
    printf("failed to open expansion.library!\n");
    return 1;
  }

  if (cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x1)) {
    printf("MNT VA2000 rev 1 found.\n");
    registers = (struct MNTSDRegs*)(((uint8*)cd->cd_BoardAddr)+cd->cd_BoardSize-0x10000+0x60);
  } else {
    printf("MNT VA2000 not found!\n");
    return 1;
  }

  printf("error reg: %d\n",registers->err);

  if (argc>1) {
    if (argv[1][0]=='r') {
      printf("resetting\n");
      registers->read = 0x00;
      registers->write = 0x00;
      registers->addr_hi = 0x00;
      registers->addr_lo = 0x00;
      registers->busy = 0xffff;
      registers->handshake = 0xffff;
      registers->handshake = 0x00;
      for (i=0;i<4;i++) {
        printf("%d\n",i);
      }
      registers->busy = 0;
      return 0;
    }
    
    block=atoi(argv[1]);
  }
  
  registers->write = 0x00;
  registers->read = 0x00;
  registers->handshake = 0x00;

  printf("busy: %d\n",registers->busy);

  if (argc>3 && argv[3][0]=='w') {
    int numblocks = 1;
    int i = 0;
    int j = 0;
    int v = 0;
    numblocks=atoi(argv[2]);

    if (argc>4) {
      v = atoi(argv[4]);
      printf("write value: %d\n",v);
    }
    if (argc>5) {
      LOOP_TIMEOUT=atoi(argv[5]);
      printf("LOOP_TIMEOUT: %d\n",LOOP_TIMEOUT);
    }
    
    for (i = 0; i<numblocks; i++) {
      //printf("write mode to block %d/%d!\n",block+i,block+numblocks-1);
      
      for (j=0; j<512; j++) {
        if (argc>4) {
          test[j]=v;
        } else {
          test[j]=block+i;
        }
      }

      sdcmd_write_blocks(registers, block+i, test, 1);
    }
    //sdcmd_write_blocks(registers, block, test, numblocks);
    
    printf("done\n");
  } else {
    int numblocks = 1;
    int i = 0;
    int j = 0;
    uint32 addr_hi;
    uint32 addr_lo;
    if (argc>2) {
      numblocks=atoi(argv[2]);
    }

    for (i = 0; i<numblocks; i++) {
      //printf("sd driver read block %d/%d:\n",block+i,block+numblocks-1);
      sdcmd_read_blocks(registers, block+i, test, 1);

      if (numblocks>1 && test[0]==block+i) {
        //printf("ok.\n");
      } else { 
        for (j=0; j<512; j++) {
          if (j%32==0) printf("\n");
          printf("%02x",test[j]);
        }
        printf("\n");
      }
    }
  }
  free(test);
}
*/
