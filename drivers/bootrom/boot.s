
# BoardBase is in a0
# DiagCopy is in a2
# ConfigDev is in a3
# Return success in d0

/*
 STRUCTURE RT,0
    UWORD RT_MATCHWORD                  ; word to match on (ILLEGAL)
    APTR  RT_MATCHTAG                   ; pointer to the above (RT_MATCHWORD)
    APTR  RT_ENDSKIP                    ; address to continue scan
    UBYTE RT_FLAGS                      ; various tag flags
    UBYTE RT_VERSION                    ; release version number
    UBYTE RT_TYPE                       ; type of module (NT_XXXXXX)
    BYTE  RT_PRI                        ; initialization priority
    APTR  RT_NAME                       ; pointer to node name
    APTR  RT_IDSTRING                   ; pointer to identification string
    APTR  RT_INIT                       ; pointer to init code
    LABEL RT_SIZE
*/
  
.set _LVOFindResident,-96
.set RT_INIT,22
  
DiagEntry:
  tst.w 0x60(a0)        /* is card busy? */
  beq start             /* no, SD card found! */
  moveq #1,d0           /* yes, so init failed */
  move.w #1, 0x4e(a0)   /* enable video capture */
  move.w #1, 0x60(a0)   /* reset SD for good measure */
  nop
  rts                   /* abort */

start:
  move.l #0, d0         /* sd block addr */
  move.l a0, a4         /* destination */
  add.l #0x10000, a4
  move.w #0, 0x68(a0)   /* sd addr hi */
  move.l #513, d1       /* byte count-1 */

read:
  move.w d0, 0x6a(a0)   /* sd addr lo */
  move.w #0xffff, 0x62(a0) /* read from SD */

blockloop:
busya:
  tst.w 0x60(a0)        /* wait until busy */
  beq busya             /* zero? */
shakea:
  tst.w 0x66(a0)        /* wait until handshake */
  beq shakea            /* zero? */
  
  move.b 0x6e(a0), d2   /* read byte from SD */
  move.b d2, (a4)+
  move.w #0xffff, 0x66(a0) /* raise handshake (ack byte) */
shakeb:
  tst.w 0x66(a0)        /* wait until no more handshake */
  bne shakeb            /* not zero? */
  move.w #0, 0x66(a0)   /* lower handshake */

  dbra d1, blockloop

  move.l a0, a4
  add.l #0x10020, a4
  cmp.w #0x4efa, (a4) /* look for a jump op */
  bne bail
  jmp (a4)
bail:
  rts

BootEntry:
  lea     DosName(pc),a1          /* 'dos.library',0 */
  jsr     _LVOFindResident(a6)    /* find the DOS resident tag */
  move.l  d0,a0                   /* in order to bootstrap */
  move.l  RT_INIT(A0),a0          /* set vector to DOS INIT */
  jsr     (a0)                    /* and initialize DOS */
  rts

DosName:
  .asciz "dos.library"
