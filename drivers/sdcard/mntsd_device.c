/*
 * Amiga SD Card Driver (mntsd.device)
 * Copyright (C) 2016, Lukas F. Hartmann <lukas@mntmn.com>
 * Based on code Copyright (C) 2016, Jason S. McMullan <jason.mcmullan@gmail.com>
 * All rights reserved.
 *
 * Licensed under the MIT License:
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <exec/resident.h>
#include <exec/errors.h>
#include <exec/memory.h>
#include <exec/lists.h>
#include <exec/alerts.h>
#include <exec/tasks.h>
#include <exec/io.h>
#include <exec/execbase.h>

#include <libraries/expansion.h>

#include <devices/trackdisk.h>
#include <devices/timer.h>
#include <devices/scsidisk.h>

#include <dos/filehandler.h>

#include <proto/exec.h>
#include <proto/disk.h>
#include <proto/expansion.h>

struct ExecBase* SysBase;

const char DevName[]="mntsd.device";
const char DevIdString[]="mntsd 1.6.1 (25 Jul 2017)";

const UWORD DevVersion=1;
const UWORD DevRevision=6;

#include "stabs.h"

#include "mntsd_cmd.h"

struct WBStartup *_WBenchMsg;
struct SDBase* SDBase;

#define debug(x,args...) while(0){};
#define kprintf(x,args...) while(0){};

//#define bug(x,args...) kprintf(x ,##args);
//#define debug(x,args...) bug("%s:%ld " x "\n", __func__, (unsigned long)__LINE__ ,##args)

void _cleanup() {
}
void _exit() {
}

void SD_InitUnit(struct SDBase* SDBase, int id, uint8* registers);
LONG SD_PerformIO(struct SDUnit* sdu, struct IORequest *io);
LONG SD_PerformSCSI(struct SDUnit* sdu, struct IORequest *io);

// struct Device is just a Library http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_3._guide/node05FB.html#line23 (dev->dd_Library)

extern void* DOSBase[2]; // part of libnix startup foo

int __UserDevInit(struct Device* dev)
{
  struct Library* ExpansionBase;
  struct ConfigDev* cd = NULL;
  uint8* registers = NULL;
  uint32 i;
  
  SysBase = *(struct ExecBase **)4L;

  //DOSBase[0]=OpenLibrary("dos.library", 0);
  //VPrintf("Hello from __UserDevInit of mntsd.device %x.%x\n",&DevVersion,&DevRevision);
  /*for (i=0;i<10;i++) {
    VPrintf("counter test: %lx\n",&i);
  }*/
  
  if ((ExpansionBase = (struct Library*)OpenLibrary("expansion.library",0L))==NULL) {
    return 0;
  }

  if (cd = (struct ConfigDev*)FindConfigDev(cd,0x6d6e,0x1)) {
    registers = ((uint8*)cd->cd_BoardAddr)+0x60;
    CloseLibrary(ExpansionBase);
  } else {
    CloseLibrary(ExpansionBase);
    return 0;
  }
  
  SDBase = AllocMem(sizeof(struct SDBase), MEMF_PUBLIC|MEMF_CLEAR);
  if (!SDBase) return 0;

  for (i = 0; i < SD_UNITS; i++) SD_InitUnit(SDBase, i, registers);
  
  //VPrintf("mntsd init done, regs: %lx\n",&registers);
  return 1;
}

int __UserDevCleanup(void)
{
  // FIXME dealloc SDBase
  return 0;
}

// http://wiki.amigaos.net/wiki/Example_Device
// http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_2._guide/node005B.html
// http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_3._guide/node0621.html
// Node: http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_3._guide/node062F.html
// IOExtTD : IOStdReq : Message : Node

/* struct Message {
    struct Node     mn_Node;
    struct MsgPort *mn_ReplyPort;
    UWORD           mn_Length;
}; */

int __UserDevOpen(struct IOExtTD *iotd, ULONG unitnum, ULONG flags)
{
  struct Node* node = (struct Node*)iotd;
  int io_err = IOERR_OPENFAIL;
  
  //debug("sd unit: %ld, flags: %lx",unitnum,flags);

  if (iotd && unitnum==0) {
    io_err = 0;
    // Mark IORequest as "complete"
    //node->ln_Type = NT_REPLYMSG;
    iotd->iotd_Req.io_Unit = (struct Unit*)&SDBase->sd_Unit[unitnum];
    iotd->iotd_Req.io_Unit->unit_flags = UNITF_ACTIVE;
    iotd->iotd_Req.io_Unit->unit_OpenCnt = 1;
  }
  
  iotd->iotd_Req.io_Error = io_err;
  return io_err;
}

int __UserDevClose(struct IOExtTD *iotd)
{
  return 0;
}

ADDTABL_1(__BeginIO,a1);
void __BeginIO(struct IORequest *io) {
  struct SDUnit* sdu;
  struct Node* node = (struct Node*)io;

  if (!SDBase) return;
  sdu = &SDBase->sd_Unit[0]; // (struct SDUnit *)io->io_Unit;
  if (!sdu) return;
  if (!io) return;
  
  //debug("io_Command = %ld, io_Flags = 0x%lx quick = %lx", io->io_Command, io->io_Flags, (io->io_Flags & IOF_QUICK));

  io->io_Error = SD_PerformIO(sdu, io);
  
  if (!(io->io_Flags & IOF_QUICK)) {
    // ReplyMsg does this: io->io_Message.mn_Node.ln_Type = NT_REPLYMSG;
    ReplyMsg(&io->io_Message);
  }
}

ADDTABL_1(__AbortIO,a1);
void __AbortIO(struct IORequest* io) {
  if (!io) return;
  io->io_Error = IOERR_ABORTED;
}


void SD_InitUnit(struct SDBase* SDBase, int id, uint8* registers)
{
  struct SDUnit *sdu = &SDBase->sd_Unit[id];

  //debug("init sdbase: %lx sdu: %lx id: %lx",SDBase,sdu,id);

  if (id == 0) {
    sdu->sdu_Registers = (void*)registers;
    sdu->sdu_Enabled = 1;  
    sdu->sdu_Present = 1;
    sdu->sdu_Valid = 1;
    sdu->sdu_ChangeNum++;
    
    sd_reset(sdu->sdu_Registers);
  }
}

uint32 SD_ReadWrite(struct SDUnit *sdu, struct IORequest *io, uint32 offset, BOOL is_write)
{
  struct IOStdReq *iostd = (struct IOStdReq *)io;
  struct IOExtTD *iotd = (struct IOExtTD *)io;
  
  uint8* data;
  uint32 len, num_blocks;
  uint32 block, max_addr;
  uint16 sderr;

  if (!sdu || !io) return 0;
  
  data = iotd->iotd_Req.io_Data;
  len = iotd->iotd_Req.io_Length;
  
  max_addr = SD_CYL_SECTORS * SD_CYLS * SD_SECTOR_BYTES;
  
  if ((offset >= max_addr) || (offset+len >= max_addr)) {
    return IOERR_BADADDRESS;
  }
  if (data == 0) {
    return IOERR_BADADDRESS;
  }
  if (len < SD_SECTOR_BYTES) {
    iostd->io_Actual = 0;
    return IOERR_BADLENGTH;
  }

  block = offset >> SD_SECTOR_SHIFT;
  num_blocks = len >> SD_SECTOR_SHIFT;
  sderr = 0;

  if (is_write) {
    uint32 retries = 10;
    do {
      debug("write %lx %lx retry %lx regs %lx",block,num_blocks,retries,sdu->sdu_Registers);
      sderr = sdcmd_write_blocks(sdu->sdu_Registers, data, block, num_blocks);
      if (sderr) {
        debug("err %x",sderr);
        sd_reset(sdu->sdu_Registers);
      }
      retries--;
    } while (sderr && retries>0);
    debug("write done");
    
    /*uint32 i, x;
    uint8 byte;
    for (i=0; i<num_blocks; i++) {
      uint32 blk = block+i;
      for (x=0; x<SD_SECTOR_BYTES; x++) {
        byte = data[(i<<SD_SECTOR_SHIFT)+x];
        TESTMEM[(blk<<SD_SECTOR_SHIFT)+x] = byte;        
      }
    }
    sderr = 0;*/
  } else {
    debug("read %lx %lx",block,num_blocks);
    sderr = sdcmd_read_blocks(sdu->sdu_Registers, data, block, num_blocks);
    if (sderr) {
      debug("err %x",sderr);
    } else {
      debug("read done");
    }
        
    /*uint32 i, x;
    uint8 byte;
    for (i=0; i<num_blocks; i++) {
      uint32 blk = block+i;
      for (x=0; x<SD_SECTOR_BYTES; x++) {
        byte = TESTMEM[(blk<<SD_SECTOR_SHIFT)+x];
        data[(i<<SD_SECTOR_SHIFT)+x] = byte;
      }
    }
    sderr = 0;*/
  }
  
  if (sderr) {
    iostd->io_Actual = 0;

    if (sderr & SDERRF_TIMEOUT)
      return TDERR_DiskChanged;
    if (sderr & SDERRF_PARAM)
      return TDERR_SeekError;
    if (sderr & SDERRF_ADDRESS)
      return TDERR_SeekError;
    if (sderr & (SDERRF_ERASESEQ | SDERRF_ERASERES))
      return TDERR_BadSecPreamble;
    if (sderr & SDERRF_CRC)
      return TDERR_BadSecSum;
    if (sderr & SDERRF_ILLEGAL)
      return TDERR_TooFewSecs;
    if (sderr & SDERRF_IDLE)
      return TDERR_PostReset;
    
    return TDERR_SeekError;
  } else {
    iostd->io_Actual = len;
  }
  
  return 0;
}

LONG SD_PerformIO(struct SDUnit *sdu, struct IORequest *io)
{
  struct IOStdReq *iostd = (struct IOStdReq *)io;
  struct IOExtTD *iotd = (struct IOExtTD *)io;
  APTR data;
  uint32 len;
  uint32 offset;
  //struct DriveGeometry *geom;
  uint32 err = IOERR_NOCMD;
  int i;

  if (!io) return err;
  if (!sdu) return err;
  if (!sdu->sdu_Enabled) {
    return IOERR_OPENFAIL;
  }

  data = iotd->iotd_Req.io_Data;
  len = iotd->iotd_Req.io_Length;

  if (io->io_Error == IOERR_ABORTED) {
    return io->io_Error;
  }

  //debug("cmd: %s",cmd_name(io->io_Command));
  //debug("IO %lx Start, io_Flags = %ld, io_Command = %ld (%s)", io, io->io_Flags, io->io_Command, cmd_name(io->io_Command));
  
  switch (io->io_Command) {
  case CMD_CLEAR:
    /* Invalidate read buffer */
    iostd->io_Actual = 0;
    err = 0;
    break;
  case CMD_UPDATE:
    /* Flush write buffer */
    iostd->io_Actual = 0;
    err = 0;
    break;
  case TD_PROTSTATUS:
    iostd->io_Actual = 0;
    err = 0;
    break;
  case TD_CHANGENUM:
    iostd->io_Actual = sdu->sdu_ChangeNum;
    err = 0;
    break;
  case TD_REMOVE:
    iostd->io_Actual = 0;
    err = 0;
    break;
  case TD_CHANGESTATE:
    iostd->io_Actual = 0;
    err = 0;
    break;
  case TD_GETDRIVETYPE:
    iostd->io_Actual = DG_DIRECT_ACCESS;
    err = 0;
    break;
  case TD_MOTOR:
    iostd->io_Actual = sdu->sdu_Motor;
    sdu->sdu_Motor = iostd->io_Length ? 1 : 0;
    err = 0;
    break;
    
  case TD_FORMAT:
    offset  = iotd->iotd_Req.io_Offset;
    err = SD_ReadWrite(sdu, io, offset, 1);
    break;
  case CMD_WRITE:
    offset  = iotd->iotd_Req.io_Offset;
    err = SD_ReadWrite(sdu, io, offset, 1);
    break;
  case CMD_READ:
    offset  = iotd->iotd_Req.io_Offset;
    err = SD_ReadWrite(sdu, io, offset, 0);
    break;
    
  case HD_SCSICMD:
    err = SD_PerformSCSI(sdu, io);
    break;
    
  default:
    //kprintf("Unknown IO command: %ld\n", io->io_Command);
    err = IOERR_NOCMD;
    break;
  }

  return err;
}

LONG SD_PerformSCSI(struct SDUnit *sdu, struct IORequest *io)
{
  struct IOStdReq *iostd = (struct IOStdReq *)io;
  struct SCSICmd *scsi = iostd->io_Data;
  uint8* registers = sdu->sdu_Registers;
  uint8* data = (uint8*)scsi->scsi_Data;
  uint32 i, block, blocks, maxblocks;
  long err;
  uint8 r1;

  /*debug("SCSI len=%ld, cmd = %02lx %02lx %02lx ... (%ld)",
        iostd->io_Length, scsi->scsi_Command[0],
        scsi->scsi_Command[1], scsi->scsi_Command[2],
        scsi->scsi_CmdLength);*/
  
  maxblocks = SD_CYL_SECTORS * SD_CYLS;
  
  if (scsi->scsi_CmdLength < 6) {
    //debug("SCSICMD BADLENGTH2");
    return IOERR_BADLENGTH;
  }

  if (scsi->scsi_Command == NULL) {
    //debug("SCSICMD IOERR_BADADDRESS1");
    return IOERR_BADADDRESS;
  }

  scsi->scsi_Actual = 0;

  switch (scsi->scsi_Command[0]) {
  case 0x00:      // TEST_UNIT_READY
    err = 0;
    break;
  case 0x12:      // INQUIRY
    for (i = 0; i < scsi->scsi_Length; i++) {
      uint8 val;

      switch (i) {
      case 0: // SCSI device type: direct-access device
        val = (0 << 5) | 0;
        break;
      case 1: // RMB = 1
        val = (1 << 7);
        break;
      case 2: // VERSION = 0
        val = 0;
        break;
      case 3: // NORMACA=0, HISUP = 0, RESPONSE_DATA_FORMAT = 2
        val = (0 << 5) | (0 << 4) | 2;
        break;
      case 4: // ADDITIONAL_LENGTH = 44 - 4
        val = 44 - 4;
        break;
      default:
        if (i >= 8 && i < 16)
          val = "MNT     "[i - 8];
        else if (i >= 16 && i < 32)
          val = "VA2000 SD Card "[i - 16];
        else if (i >= 32 && i < 36)
          val = "1.5  "[i-32];
        else if (i >= 36 && i < 44) {
          val = '1';
        } else
          val = 0;
        break;
      }
      data[i] = val;
    }

    scsi->scsi_Actual = i;
    err = 0;
    break;
  case 0x08: // READ (6)
    
    block = scsi->scsi_Command[1] & 0x1f;
    block = (block << 8) | scsi->scsi_Command[2];
    block = (block << 8) | scsi->scsi_Command[3];
    blocks = scsi->scsi_Command[4];

    debug("scsi_read %lx %lx\n",block,blocks);
    
    if (block + blocks > maxblocks) {
      err = IOERR_BADADDRESS;
      break;
    }
    if (scsi->scsi_Length < (blocks << SD_SECTOR_SHIFT)) {
      err = IOERR_BADLENGTH;
      break;
    }
    if (data == NULL) {
      err = IOERR_BADADDRESS;
      break;
    }
    
    r1 = sdcmd_read_blocks(registers, data, block, blocks);
    if (r1) {
      err = HFERR_BadStatus;
      break;
    }

    scsi->scsi_Actual = scsi->scsi_Length;
    err = 0;
    break;
  case 0x0a: // WRITE (6)
    block = scsi->scsi_Command[1] & 0x1f;
    block = (block << 8) | scsi->scsi_Command[2];
    block = (block << 8) | scsi->scsi_Command[3];
    blocks = scsi->scsi_Command[4];
    if (block + blocks > maxblocks) {
      err = IOERR_BADADDRESS;
      break;
    }
    if (scsi->scsi_Length < (blocks << SD_SECTOR_SHIFT)) {
      err = IOERR_BADLENGTH;
      break;
    }
    if (data == NULL) {
      err = IOERR_BADADDRESS;
      break;
    }
    debug("scsi_write %lx %lx\n",block,blocks);
    r1 = sdcmd_write_blocks(registers, data, block, blocks);
    if (r1) {
      err = HFERR_BadStatus;
      break;
    }

    scsi->scsi_Actual = scsi->scsi_Length;
    err = 0;
    break;
  case 0x25: // READ CAPACITY (10)
    if (scsi->scsi_CmdLength < 10) {
      err = HFERR_BadStatus;
      break;
    }

    block = *((uint32*)&scsi->scsi_Command[2]);
    
    if ((scsi->scsi_Command[8] & 1) || block != 0) {
      // PMI Not supported
      err = HFERR_BadStatus;
      break;
    }

    if (scsi->scsi_Length < 8) {
      err = IOERR_BADLENGTH;
      break;
    }

    ((uint32*)data)[0] = maxblocks-1;
    ((uint32*)data)[1] = SD_SECTOR_BYTES;

    scsi->scsi_Actual = 8;    
    err = 0;
    
    break;
  case 0x1a: // MODE SENSE (6)    
    data[0] = 3 + 8 + 0x16;
    data[1] = 0; // MEDIUM TYPE
    data[2] = 0;
    data[3] = 8;
    if (maxblocks > (1 << 24))
      blocks = 0xffffff;
    else
      blocks = maxblocks;
    data[4] = (blocks >> 16) & 0xff;
    data[5] = (blocks >>  8) & 0xff;
    data[6] = (blocks >>  0) & 0xff;
    data[7] = 0;
    data[8] = 0;
    data[9] = 0;
    data[10] = (SD_SECTOR_BYTES >> 8) & 0xff;
    data[11] = (SD_SECTOR_BYTES >> 0) & 0xff;
    
    switch (((UWORD)scsi->scsi_Command[2] << 8) | scsi->scsi_Command[3]) {
    case 0x0300: // Format Device Mode
      for (i = 0; i < scsi->scsi_Length - 12; i++) {
        UBYTE val;

        switch (i) {
        case 0: // PAGE CODE
          val = 0x03;
          break;
        case 1: // PAGE LENGTH
          val = 0x16;
          break;
        case 2: // TRACKS PER ZONE 15..8
          val = (SD_HEADS >> 8) & 0xff;
          break;
        case 3: // TRACKS PER ZONE 7..0
          val = (SD_HEADS >> 0) & 0xff;
          break;
        case 10: // SECTORS PER TRACK 15..8
          val = (SD_TRACK_SECTORS >> 8) & 0xff;
          break;
        case 11: // SECTORS PER TRACK 7..0
          val = (SD_TRACK_SECTORS >> 0) & 0xff;
          break;
        case 12: // DATA BYTES PER PHYSICAL SECTOR 15..8
          val = (SD_SECTOR_BYTES >> 8) & 0xff;
          break;
        case 13: // DATA BYTES PER PHYSICAL SECTOR 7..0
          val = (SD_SECTOR_BYTES >> 0) & 0xff;
          break;
        case 20: // HSEC = 1, RMB = 1
          val = (1 << 6) | (1 << 5);
          break;
        default:
          val = 0;
          break;
        }

        data[12 + i] = val;
      }

      scsi->scsi_Actual = data[0] + 1;
      err = 0;
      break;
    case 0x0400: // Rigid Drive Geometry
      for (i = 0; i < scsi->scsi_Length - 12; i++) {
        UBYTE val;

        switch (i) {
        case 0: // PAGE CODE
          val = 0x04;
          break;
        case 1: // PAGE LENGTH
          val = 0x16;
          break;
        case 2: // CYLINDERS 23..16
          val = (SD_CYLS >> 16) & 0xff;
          break;
        case 3: // CYLINDERS 15..8
          val = (SD_CYLS >> 8) & 0xff;
          break;
        case 4: //  CYLINDERS 7..0
          val = (SD_CYLS >> 0) & 0xff;
          break;
        case 5: // HEADS
          val = SD_HEADS;
          break;
        default:
          val = 0;
          break;
        }

        data[12 + i] = val;
      }

      scsi->scsi_Actual = data[0] + 1;
      err = 0;
      break;
    default:
      err = HFERR_BadStatus;
      break;
    }
    break;
  default:
    err = IOERR_NOCMD;
    break;
  }

  if (err == 0) {
    iostd->io_Actual = sizeof(*scsi);
  }
  else {
    iostd->io_Actual = 0;
  }

  return err;
}

ADDTABL_END();
