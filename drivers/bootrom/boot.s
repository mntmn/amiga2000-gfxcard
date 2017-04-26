
# BoardBase is in a0
# DiagCopy is in a2
# ConfigDev is in a3
# Return success in d0

DiagEntry:
  move.l #0, d0         /* sd block addr */
  move.l a0, a4         /* destination */
  add.l #0x10000, a4
  move.w #0, 0x68(a0)   /* sd addr hi */
  move.l #513, d1       /* block count-1 */

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
  jmp a4

