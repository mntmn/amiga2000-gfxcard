/* ConfigDev passed in a3 */
/*
  struct ConfigDev {
    struct Node		cd_Node; // 0  2ptr,2byte,1ptr = 14byte
    UBYTE		cd_Flags; // 14
    UBYTE		cd_Pad; // 15
    struct ExpansionRom	cd_Rom; // 16   16bytes
    APTR		cd_BoardAddr; // 32
    ...
*/
.set SysBase,4
.set OpenLibrary,-552
.set CloseLibrary,-414
.set PutStr,-948
.set VPrintf,-954
.set AllocMem,-198
.set FindResident,-96
  
start:
  jmp realstart(pc)
handover:
  jmp trampoline(pc)

.align 4
sdread:
  /* a4 = destination, a0 = va2000 regs */
  move.l a4,-(a7)
  move.l #0, d0         /* sd block addr */
  move.w #0, 0x68(a0)   /* sd addr hi */

  move.l #100, d3        /* 63 blocks */
blockloop:
  move.l #513, d1       /* byte count-1 */

read:
  move.w d0, 0x6a(a0)   /* sd addr lo */
  move.w #0xffff, 0x62(a0) /* read from SD */

byteloop:
busya:
  tst.w 0x60(a0)        /* wait until busy */
  beq busya             /* zero? */
  
shakea:
  tst.w 0x66(a0)        /* wait until handshake */
  beq shakea            /* zero? */
  
  move.w #0, 0x62(a0)   /* disable read */

  move.b 0x6e(a0), d2   /* read byte from SD */
  move.b d2, (a4)+
  move.l d2, 0xdff180
  move.w #0xffff, 0x66(a0) /* raise handshake (ack byte) */
shakeb:
  tst.w 0x66(a0)        /* wait until no more handshake */
  bne shakeb            /* not zero? */
  move.w #0, 0x66(a0)   /* lower handshake */

  dbra d1, byteloop
  
  add.w #1, d0          /* increase block address */
  sub.l #2, a4          /* remove checksum from block */
  dbra d3, blockloop
  
  move.l (a7)+,a4
  rts

.align 4
realstart:
  move.l a6,-(a7)
  move.l a3,-(a7)  /* save configdev address */
  /*move.l  32(a3), a0 */
  move.l a0,-(a7)  /* save board address */

  movea.l	SysBase,a6 /* allocate RAM for loading ourselves to */
  move.l #0x40000,d0
  moveq #0,d1 /* MEMF_ANY */
  jsr AllocMem(a6)
  tst.l	d0
  beq allocfail
  
  move.l d0, a4 /* load addr */
  /* read first 63 blocks into vram twice */
  move.l (a7)+,a0  /* restore board address */
  jsr     sdread(pc)
  jsr     sdread(pc)
  
  move.l (a7)+,a3 /* restore configdev address from stack */
  jmp 0x24(a4) /* jmp to handover at new memory location (0x20+0x04) */
  
.align 4
allocfail:  
  move.l d1,0xdff180
  add.l #1,d1
  bra allocfail
  
  /* we will arrive here in our copy in amiga RAM */
  /* a0 contains board addr, a3 contains configdev addr */
.align 4
trampoline:
	lea	configdev(pc),a1
  move.l a3,(a1) /* store configdev pointer */

  move.w #1, 0x4e(a0) /* activate video capture that was switched off in ROM */
  move.l a4, a0 /* board addr not needed anymore, keep loadaddr in a0 */
  
  /* add resident ---------------------- */

  /* mntsd.device is at loadaddr + 0x400 (skip 2 blocks) */
  move.l  a0,-(a7)
  add.l   #0x400, a0
  /* relocate the binary (hunk) */
  jsr     relocstart(pc)
  move.l  (a7)+, a0 /* address of loaded mntsd.device */
  move.l  a0, a4
  move.l  a4, a1 /* restore board addr */
  
  add.l   #0x400+0x180, a1 /* start of mntsd.device + $180 = romtag FIXME */
  move.l  #0, d1 /* no seglist */
  move.l  4,a6
  jsr     -102(a6) /* InitResident */
  /* object = InitResident(resident, segList) */
	/* D0	                   A1        D1 */
  
  /* make dos node --------------------- */
  
  jmp initdos(pc)

.align 4
configdev:
  .long 0
  
/*fmthunks:
  .asciz "hunks: %ld\n"
fmtaddr:
  .asciz "addr: %lx\n"
fmtpatchaddr:
  .asciz "  patched: %lx\n"
fmtrelocnum:
  .asciz "num relocs: %ld\n"
fmtdebug:
  .asciz "debug: %lx\n"
fmtdebugs:
  .asciz "debugs: %s\n"
fmtpointseg:
  .asciz "  point to: %ld\n"
dosbase:
  .long 0*/
segtprs:
  .long 0
  .long 0

.align 4
relocstart:
  lea.l  segptrs(pc), a1
  
	move.l 8(a0), d4 /* number of hunks */
  move.l #0, d5

  /*
    a0: executable base addr
    a1: segptrs
    a2: addr of hunk0

    d4: numhunks
    d5: pass#
    d6: current hunk addr
  */

  /* hunk 0 address in memory */
	move.l a0, d6
  add.l  #0x24, d6
	move.l d6, a2 /* addr of first hunk */
  move.l d6, (a1) /* store pointer to this hunk in segptrs[1] */

relocpass:
	move.l a2, a3
	move.l 0x14(a0), d0 /* ptr to first hunk size */
  
	lsl.l  #2, d0 /* firsthunk + first size */
	add.l  d0, a3 /* end of first hunk, start of reloc table */

  jsr  reloctables(pc)

  add.l  #4, a3 /* skip hunk_end */
  add.l  #4, a3 /* skip hunk_data */
  move.l (a3)+, d0 /* size of data hunk */
  lsl.l  #2, d0

  move.l a3, 4(a1) /* store pointer to this hunk in segptrs[1] */
  move.l a3, d6 /* save current hunk ptr for patching CHECKME */
  add.l  d0, a3 /* arrive at reloc tables of data hunk */

  jsr   reloctables(pc)

  cmp #1, d5
  bge rcomplete

  /* start pass 1 */
  move.l #1, d5
	move.l a2, d6 /* addr of first hunk */
  bra relocpass

rcomplete:
  rts

.align 4
reloctables:
  move.l (a3)+, d2 /* skip 0000 03ec marker */
reloctable:
	move.l (a3)+, d2 /* number of relocs to process */

  tst.w  d2
	beq    relocdone /* done if zero */
  
  move.l (a3)+, d1  /* segment number to point to */

  lsl.l #2, d1
  move.l (a1,d1), d1 /* offset to add to target slots */
  
  bra rloop
relocloop:
  move.l (a3)+, a4

  tst.w d5 /* pass = 0? */
  beq rloop

  /* pass = 1, so patch */
  add.l  d6, a4 /* add current hunk address */
  add.l  d1, (a4) /* the actual patching */
  
  move.l d1, 0xdff180
rloop:
	dbra   d2, relocloop
  jmp reloctable(pc)
relocdone:
  rts

/*.align 4
printf:
  move.l a6,-(a7)
  move.l dosbase(pc),a6
  move.l a1, d1
  lea.l fmtnum(pc),a1
  move.l d2,(a1)
  move.l a1, d2
	jsr	VPrintf(a6)
  move.l (a7)+,a6
  rts
  
.align 4
fmtnum:
  .long 0*/

.align 4
initdos:  
  move.l  4,a6
  lea     expansionname(pc),a1

  moveq   #37, d0
  jsr     OpenLibrary(a6) /* open expansion.library */
  tst.l   d0
  beq.s   nodos
  move.l  d0,a6

    /*movem.l a0-a6/d0-d6,-(a7)
    move.l #0xbeef,d2
    lea.l fmtdebug(pc),a1
    jsr printf(pc)
    movem.l (a7)+,a0-a6/d0-d6*/

  lea     dosnode(pc),a0
  lea     diskname(pc),a1
  move.l  a1,(a0) /* store in parmpkt */
  lea     devicename(pc),a1
  move.l  a1,4(a0) /* store in parmpkt */
  
  jsr     -144(a6) /* MakeDosNode */
  move.l  d0, a0 /* fresh device node */
  
  /* add boot node --------------------- */
  
  move.l  #0, d0
  move.l  #0, d1
  move.l configdev(pc),a1
  /*move.l  #0, a1*/ /* later put ConfigDev here (a3) */
  jsr     -36(a6) /* AddBootNode */
  
  move.l  a6,a1 /* close expansion library */
  move.l  4,a6
  jsr     CloseLibrary(a6)
  moveq   #1,d0
  move.l  (a7)+,a6
  rts
  
nodos:
  move.l d1,0xdff180
  add.l #1,d1
  bra nodos

  moveq   #1,d0
  move.l  (a7)+,a6
  rts

.align 4
diskname:
  .asciz "MNT0"
.align 4
devicename:
  .asciz "mntsd.device"
.align 4
expansionname:
  .asciz "expansion.library"
.align 4
dosnode:
  .long 0 /* dos disk name */
  .long 0 /* device file name */
  .long 0 /* unit */
  .long 0 /* flags */
  .long 16 /* length of node? */
  .long 128 /* longs in a block */
  .long 0
  .long 4 /* surfaces */
  .long 1 /* sectors per block */
  .long 256 /* blocks per track */
  .long 2 /* reserved bootblocks 256 = 128KB */
  .long 0
  .long 0
  .long 2  /* lowcyl FIXME */
  /*.long 2047*/ /* hicyl */
  .long 1023
  .long 10 /* buffers */
  .long 0 /* MEMF_ANY */
  .long 0x0001fe00 /* MAXTRANS */
  .long 0x7ffffffe /* Mask */
  .long -1 /* boot prio */
  .long 0x444f5303 /* dostype: DOS3 */
