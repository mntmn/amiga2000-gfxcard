#include <stdio.h>

#include <libraries/expansion.h>
#include <libraries/configvars.h>
#include "../gfx_vbcc/va2000.h"

#define uint8_t unsigned char
#define uint16_t unsigned short

struct ExecBase* SysBase;
struct Library* ExpansionBase;

int main(int argc, char** argv) {
  struct ConfigDev* cd = NULL;
  uint8_t* memory;
  MNTVARegs* regs;
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
    regs = (MNTVARegs*)(cd->cd_BoardAddr);
    fw = *((uint16_t*)regs);
    if (fw<83) {
      printf("This tool needs at least VA2000 Firmware 1.8.3 to operate. Found: %d\n", fw);
      return 1;
    }
  } else {
    printf("MNT VA2000 not found!\n");
    return 1;
  }

  if ((argc==4 || argc==5) && !strcmp(argv[1],"mode")) {
    uint16_t width, height;
    width = atoi(argv[2]);
    height = atoi(argv[3]);
    regs->capture_default_screen_w = width;
    regs->capture_default_screen_h = height;
    if (argc==5 && !strcmp(argv[4],"apply")) {
      regs->screen_w = width;
      regs->screen_h = height;
    }
  } else if ((argc==3 || argc==4) && !strcmp(argv[1],"voffset")) {
    uint16_t voffset = atoi(argv[2]);
    regs->videocap_voffset = voffset;
    //if (argc==4 && !strcmp(argv[3],"apply")) {
    //  regs->pan_ptr_lo = 1024*voffset;
    //}
  } else if (argc==3 && !strcmp(argv[1],"hoffset")) {
    uint16_t hoffset = atoi(argv[2]);
    regs->videocap_prex = hoffset;
  } else if (argc==3 && !strcmp(argv[1],"vsize")) {
    uint16_t vsize = atoi(argv[2]);
    regs->capture_h = vsize;
  } else if (argc==3 && !strcmp(argv[1],"hsize")) {
    uint16_t hsize = atoi(argv[2]);
    regs->capture_w = hsize;
  } else if (argc==2) {
    shift = atoi(argv[1]);

    if (shift<0) {
      shift=-shift;
      op=0;
    }

    // reset capture clock shift
    regs->dcm7_rst = 1;

    for (i=0; i<shift; i++) {
      regs->dcm7_psincdec = op;
      usleep(1000*50);
    }
  } else {
    printf("MNT VA2000CX Adjustment Tool 1.8.3\n");
    printf("Usage:\n\nPhase Shift (value between -255 and 255):\nva2000cx 220\n\n");
    printf("Target Screenmode (default 640 480):\nva2000cx mode 640 512\nva2000cx mode 640 512 apply (set mode immediately)\n\n");
    printf("Horizontal Offset (default 64):\nva2000cx hoffset 40\n\n");
    printf("Vertical Offset (default 40):\nva2000cx voffset 40\n\n");
  }
}
