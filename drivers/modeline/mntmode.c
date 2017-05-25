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
  uint16_t* reg;
  uint16_t val;
  int i;
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
    printf("MNT VA2000 (board 1.0, fw 1.%hu) found.\n",fw);
    printf("memory at: %p regs at: %p\n",memory,regs);
  } else {
    printf("MNT VA2000 not found!\n");
    return 1;
  }

  for (i=1; i<argc; i++) {
    val = atoi(argv[i]);
    if (i==1) {
      // hres
      reg = (uint16_t*)(regs+0x06);
    }
    else if (i==5) {
      // vres
      reg = (uint16_t*)(regs+0x08);
    }
    else if (i<5) {
      reg = (uint16_t*)(regs+0x70+(i-2)*2);
    }
    else {
      reg = (uint16_t*)(regs+0x70+(i-3)*2);
    }
    printf("reg: %lx val: %d (%x)\n",reg,val,val);
    *reg = val;
  }
}
