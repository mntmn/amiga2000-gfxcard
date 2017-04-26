/*_LVOOpenLibrary EQU -552
_LVOCloseLibrary EQU -414
_LVOOutput EQU -60
_LVOWrite EQU -48 */

/* ConfigDev passed in a3 */

start:
  move.l  a6,-(a7)
  lea     0x200000, a0
  jsr     sdread(pc)
  lea     0x200000, a0
  jsr     sdread(pc)
  
  /* add resident ---------------------- */

  move.l  #0x210224, d2
  /*lea     0x210380, a2
  add.l   d2, 2(a2)
  add.l   d2, 6(a2)
  add.l   d2, 14(a2)
  add.l   d2, 18(a2)
  add.l   d2, 22(a2)
  add.l   d2, -4(a2)
  add.l   d2, -12(a2)*/

  lea     0x210200, a0
  jsr     relocstart(pc)

  /*
00001050: 0000 0007 0000 008c 0000 005a 0000 000c  ...........Z....
00001060: 0000 0006 0000 022a 0000 0240 ffff ffff  .......*...@....
  */
  
  /* object = InitResident(resident, segList) */
	/* D0	                   A1        D1 */

  move.l  0x00000004,a6
  lea     0x210380, a1 /* start of mntsd.device + $180 = romtag */
  move.l  #0, d1 /* no seglist */
  jsr     -102(a6) /* InitResident */  
  /* rom: f80f4c */
  
  /* make dos node --------------------- */
  
  move.l  0x00000004,a6
  lea     expansionname(pc),a1
  jsr     -552(a6) /* open expansion.library */
  tst.l   d0
  beq.s   nodos
  move.l  d0,a6
  
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
  move.l  #0, a1 /* later put ConfigDev here (a3) */
  jsr     -36(a6) /* AddBootNode */

  move.l  a6,a1 /* close expansion library */
  move.l  0x00000004,a6
  jsr     -414(a6)

nodos:
  moveq   #1,d0
  move.l  (a7)+,a6
  rts
erropen:
  jsr -132(a6) /* IoErr() */
  move d0, d1
  jsr -474(a6) /* PrintFault() */
  move.l  (a7)+,a6
  rts
  
sdread:
  move.l #1, d0         /* sd block addr */
  move.l a0, a4         /* destination */
  add.l #0x10200, a4
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
  move.w #0xffff, 0x66(a0) /* raise handshake (ack byte) */
shakeb:
  tst.w 0x66(a0)        /* wait until no more handshake */
  bne shakeb            /* not zero? */
  move.w #0, 0x66(a0)   /* lower handshake */

  dbra d1, byteloop
  
  add.w #1, d0          /* increase block address */
  sub.l #2, a4          /* remove checksum from block */
  dbra d3, blockloop  
  rts


  
relocstart:
	move.l 8(a0), d3 /* number of hunks */
  move.l d3, d4
	move.l a0, a1
	add.l  #0x14, a1 /* ptr to first hunk size */

/* 0: hunk address in memory */
	move.l a0, d6
  add.l  #0x24, d6

	move.l d6, a2 /* addr of first hunk */

	move.l a2, a3
	move.l 0x14(a0), d0 /* ptr to first hunk size */	
	lsl.l  #2, d0 /* firsthunk + first size */
	add.l  d0, a3 /* end of first hunk, start of reloc table */

  move.l #1, d4 /* 2 times */
  move.l d6, d1 /* start with hunk 0... */
reloctables:  
  move.l (a3)+, d5 /* skip 0000 03ec marker */
reloctable:
	move.l (a3)+, d2 /* number of relocs to process */
	beq    relocdone /* done if zero */
  
  /*move.l (a3)+, d1*/  /* segment number to point to */
  add.l #4, a3

  bra rloop
relocloop:
  move.l (a3)+, a4
  add.l  d6, a4 /* add hunk address */
  add.l  d1, (a4) /* the actual patching */
  move.l (a4), -4(a3) /* debug */
rloop:
	dbra   d2, relocloop
  move.l  #0x210fe0, d1 /* FIXME data hunk */
  jmp reloctable

  add.l  #4, a3 /* skip hunk_end */
  add.l  #4, a3 /* skip hunk_data */
  move.l (a3)+, d0 /* size of data hunk */
  lsl.l  #2, d0
  add.l  d0, a3 /* arrive at reloc hunk */

  move.l d6, d1
  move.l #0x210fe0, d6 /* FIXME data hunk */
  dbra   d4, reloctables
  
relocdone:
  rts

  

dosname:
  .asciz "dos.library"
devicename:
  .asciz "mntsd.device"
diskname:
  .asciz "MNT0"
expansionname:
  .asciz "expansion.library"
dosnode:
  .long 0 /* dos disk name */
  .long 0 /* device file name */
  .long 0 /* unit */
  .long 0 /* flags */
  .long 16 /* length */
  .long 128 /* longs in a block */
  .long 0
  .long 1 /* surfaces */
  .long 1 /* sectors per block */
  .long 1024 /* blocks per track */
  .long 256 /* reserved bootblocks = 128KB */
  .long 0
  .long 0
  .long 256  /* lowcyl FIXME */
  .long 1024 /* hicyl */
  .long 10 /* buffers */
  .long 0 /* MEMF_ANY */
  .long 0x00007fff /* MAXTRANS */
  .long 0xfffffffe /* addmask ?! */
  .long 0 /* boot prio */
  .long 0x444f5303 /* dostype: DOS3 */


