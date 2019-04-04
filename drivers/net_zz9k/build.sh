export VBCC=$HOME/code/vbcc
export PATH=$PATH:$VBCC/bin
export SDK="-I$VBCC/targets/m68k-amigaos/include -I$VBCC/targets/m68k-amigaos/include2"

#vc +aos68k -v -nostdlib $SDK -c99 -O2 -o test.device library.c
make
