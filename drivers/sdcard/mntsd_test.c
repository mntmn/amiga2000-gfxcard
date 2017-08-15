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

#include <proto/exec.h>
#include <proto/disk.h>
#include <proto/expansion.h>

#include "mntsd_cmd.h"

int main(int argc, char** argv) {
  unsigned int i=0;
  unsigned int block=0;

  struct Library* ExpansionBase;
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  struct ConfigDev* cd = NULL;
  struct MNTSDRegs* registers = NULL;
  uint8* data = NULL;
  int res = 0;

  printf("MNT VA2000 SD card test v2\n");
  
  if ((ExpansionBase = (struct Library*)OpenLibrary("expansion.library",0L))==NULL) {
    printf("failed to open expansion.library!\n");
    return 1;
  }

  if (cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x1)) {
    printf("MNT VA2000 rev 1 found.\n");
    registers = (struct MNTSDRegs*)(((uint8*)cd->cd_BoardAddr)+0x60);
  } else {
    printf("MNT VA2000 not found!\n");
    return 1;
  }

  printf("Error register: %d\n",registers->err);

  printf("Resetting...\n");
  sd_reset(registers);
  printf("done\n");

  data=(uint8*)malloc(100*512);
  memset(data,0xfe,100*512);

  printf("1 blocks write test...\n");
  res=sdcmd_write_blocks(registers,data,1000000,1); // approx. at 488 MB
  printf("done. res=%d\n",res);
  sd_reset(registers);

  printf("10 blocks write test...\n");
  res=sdcmd_write_blocks(registers,data,1000000,10); // approx. at 488 MB
  printf("done. res=%d\n",res);
  sd_reset(registers);

  printf("100 blocks write test...\n");
  res=sdcmd_write_blocks(registers,data,1000000,100); // approx. at 488 MB
  printf("done. res=%d\n",res);
  sd_reset(registers);

  printf("1000 blocks write test...\n");
  res=sdcmd_write_blocks(registers,data,1000000,1000); // approx. at 488 MB
  printf("done. res=%d\n",res);
  sd_reset(registers);

  printf("10000 blocks write test...\n");
  res=sdcmd_write_blocks(registers,data,1000000,10000); // approx. at 488 MB
  printf("done. res=%d\n",res);

  free(data);
}
