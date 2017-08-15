export CROSSPATH=/media/storage2/amiga-code/m68k-amigaos
export GCCLIBPATH=$CROSSPATH/lib/gcc-lib/m68k-amigaos/2.95.3
export PATH=$CROSSPATH/bin:$GCCLIBPATH:$PATH
export GCC_EXEC_PREFIX=m68k-amigaos
export LIBS=$CROSSPATH/lib

m68k-amigaos-as boot.s
m68k-amigaos-objdump -D a.out
