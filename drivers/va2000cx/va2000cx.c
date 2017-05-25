#include <stdio.h>

#include <libraries/expansion.h>
#include <libraries/configvars.h>

#define uint8_t unsigned char
#define uint16_t unsigned short

struct ExecBase* SysBase;
struct Library* ExpansionBase;

int main(int argc, char** argv) {
  struct ConfigDev* cd = NULL;
  uint8_t* regs;
  uint8_t* memory;
  volatile uint16_t* reg;
  int shift;
  int i;
  int op = 0xffff;
  uint16_t fw = 0;
  
  SysBase = *(struct ExecBase **)4L;
  
  if ((ExpansionBase = (struct Library*)OpenLibrary("expansion.library",0L))==NULL) {
    printf("failed to open expansion.library!\n");
    return 2;
  }
  
  if (cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x1)) {
    memory = (uint8_t*)(cd->cd_BoardAddr)+0x10000;
    regs = (uint8_t*)(cd->cd_BoardAddr);
    fw = *((uint16_t*)regs);
    if (fw<5) {
      printf("This tool needs at least VA2000 Firmware 1.5 to operate. Found: %d\n", fw);
      return 1;
    }
  } else {
    printf("MNT VA2000 not found!\n");
    return 1;
  }

  shift = atoi(argv[1]);

  if (shift<0) {
    shift=-shift;
    op=0;
  }
  
  reg = (volatile uint16_t*)(regs+0x4c); // reset
  *reg = 1;

  for (i=0; i<shift; i++) {
    reg = (volatile uint16_t*)(regs+0x4a);
    *reg = op;
    usleep(1000*50);
  }
}
