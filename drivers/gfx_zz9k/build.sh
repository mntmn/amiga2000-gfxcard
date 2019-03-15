export VBCC=$HOME/code/vbcc
export PATH=$PATH:$VBCC/bin

vc +aos68k -nostdlib -I../../../amiga-sdkinclude -c99 -O2 -o mntgfx.card mntgfx.c -ldebug -lamiga
