
#include <stdio.h>
#define uint32_t unsigned long
#define OFFSET 0x31326

int main() {
  unsigned char buf[10];
  uint32_t* buf32=((uint32_t*)buf);
  FILE* file;
  file = fopen("LIBS:Picasso96/rtg.library", "r+");
  if (!file) {
    printf("Error opening LIBS:Picasso96/rtg.library\r\n");
    return 1;
  }
  fseek(file,OFFSET,SEEK_SET);
  fread(buf,1,8,file);

  if (buf32[0]==0x4eb90001 && buf32[1]==0x5cb66032) {
    printf("rtg.library not yet patched. Patching.\r\n");
    buf[0]=0x60; // bra.s
    buf[1]=0x04; // #4
  } else if (buf32[0]==0x60040001 && buf32[1]==0x5cb66032) {
    printf("rtg.library was already patched. Unpatching.\r\n");
    buf[0]=0x4e;
    buf[1]=0xb9;
  } else {
    printf("Error: rtg.library version mismatch. Only version 40.3945 is supported.\r\n");
    return 1;
  }

  fseek(file,OFFSET,SEEK_SET);
  if (fwrite(buf,1,4,file)) {
    printf("Success.\r\n");
    fclose(file);
    return 0;
  } else {
    printf("Error: could not write to file.\r\n");
    fclose(file);
    return 1;
  }
}
