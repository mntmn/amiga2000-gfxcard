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

const char DevName[]="mntsd.device";
const char DevIdString[]="mntsd.device 1.0";

const UWORD DevVersion=1;
const UWORD DevRevision=0;

#include "stabs.h"

#include "mntsd_cmd.h"

struct SDBase* SDBase;

//static int task_running = 0;

#define SD_HEADS    16
#define SD_SECTORS  64
#define SD_RETRY 300

#define debug(x,args...) while(0){};

//#define bug(x,args...) kprintf(x ,##args);
//#define debug(x,args...) bug("%s:%ld " x "\n", __func__, (unsigned long)__LINE__ ,##args)

void SD_InitUnit(struct SDBase * SDBase, int id);

int __UserDevInit(struct Device* dev)
{
  struct Library* ExpansionBase;
  ULONG i;
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  //task_running = 0;

  SDBase = AllocVec(sizeof(struct SDBase), MEMF_CLEAR);

  debug("__UserDevInit, alloc sdbase: %lx (%ld bytes)",SDBase,sizeof(struct SDBase));
  if (!SDBase) return 0;

  SDBase->sd_Device = dev;
  dev->dd_Library.lib_Flags |= LIBF_DELEXP;
  
  for (i = 0; i < SD_UNITS; i++) SD_InitUnit(SDBase, i);

  return 1;
}

int __UserDevCleanup(void)
{
  struct IORequest io = {};
  int i;
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  //debug("__userDevCleanup");

  /*for (i = 0; i < SD_UNITS; i++) {
    io.io_Device = SDBase->sd_Device;
    io.io_Unit = &SDBase->sd_Unit[i].sdu_Unit;
    io.io_Flags = 0;
    io.io_Command = 0xffff; // kill unit task
    DoIO(&io);
    RemTask(&SDBase->sd_Unit[i].sdu_Task);
  }*/
  return 0;
}

int __UserDevOpen(struct IOExtTD *iotd, ULONG unitnum, ULONG flags)
{
  //struct SDBase* SDBase = &SDBaseStruct;
  debug("__UserDevOpen: %ld, sdbase: %lx",unitnum,SDBase);

  if (!iotd) return 0;
  
  iotd->iotd_Req.io_Error = IOERR_OPENFAIL;
  if (unitnum < SD_UNITS) {
    struct SDUnit *sdu;

    iotd->iotd_Req.io_Device = SDBase->sd_Device;
    iotd->iotd_Req.io_Error = 0;

    sdu = &SDBase->sd_Unit[unitnum];
    if (!sdu) return 0;
    
    if (sdu->sdu_Enabled) {
      sdu->sdu_Unit.unit_OpenCnt++;
    }
  }
  
  return iotd->iotd_Req.io_Error == 0;
}

int __UserDevClose(struct IOExtTD *iotd)
{
  //debug("mntsd __UserDevClose");
  //if (!iotd) return;
  //if (!iotd->iotd_Req.io_Unit) return;
  
  //iotd->iotd_Req.io_Unit->unit_OpenCnt--;

  return 0;
}

LONG SD_PerformIO(struct SDUnit* sdu, struct IORequest *io);

ADDTABL_1(__BeginIO,a1);
void __BeginIO(struct IORequest *io) {
  struct SDUnit* sdu;
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  
  if (!SDBase) return;
  sdu = &SDBase->sd_Unit[0]; // (struct SDUnit *)io->io_Unit;
  if (!sdu) return;
  if (!io) return;
  
  //debug("io_Command = %ld, io_Flags = 0x%lx", io->io_Command, io->io_Flags);

  if (io->io_Flags & IOF_QUICK) {
    /* Commands that don't require any IO */
    switch(io->io_Command)
    {
    case TD_GETNUMTRACKS:
    case TD_GETDRIVETYPE:
    case TD_GETGEOMETRY:
    case TD_REMCHANGEINT:
    case TD_ADDCHANGEINT:
    case TD_PROTSTATUS:
    case TD_CHANGENUM:
      io->io_Error = SD_PerformIO(sdu, io);
      io->io_Message.mn_Node.ln_Type=NT_MESSAGE;
      return;
    }
  }

  /* Not done quick */
  //io->io_Flags &= ~IOF_QUICK;

  /* Forward to the unit's IO task */
  //debug("Msg %lx (reply %lx) => MsgPort %lx", &io->io_Message, io->io_Message.mn_ReplyPort, sdu->sdu_MsgPort);
  //PutMsg(sdu->sdu_MsgPort, &io->io_Message);

  SD_PerformIO(sdu, io);
}

ADDTABL_1(__AbortIO,a1);
void __AbortIO(struct IORequest* io) {
  if (!io) return;
  io->io_Error = IOERR_ABORTED;
}

void SD_Detect(struct SDUnit *sdu) {
  BOOL present;
  struct ExecBase* SysBase = *(struct ExecBase **)4L;

  debug("sdu: %lx\n",sdu);
  if (!sdu) {
    debug("");
    return;
  }
  
  present = sdcmd_present(&sdu->sdu_SDCmd);
  if (present != sdu->sdu_Present) {
    if (present) {
      UBYTE sderr;

      sderr = sdcmd_detect(&sdu->sdu_SDCmd);
      
      Forbid();
      sdu->sdu_Present = TRUE;
      sdu->sdu_ChangeNum++;
      sdu->sdu_Valid = (sderr == 0) ? TRUE : FALSE;
      Permit();
    } else {
      Forbid();
      sdu->sdu_Present = FALSE;
      sdu->sdu_Valid = FALSE;
      Permit();
    }
  }
}

#define CMD_NAME(x) if (cmd == x) return #x
#define TD_READ64     24
#define TD_WRITE64    25
#define TD_SEEK64     26
#define TD_FORMAT64   27

inline const char *cmd_name(int cmd)
{
  CMD_NAME(CMD_READ);
  CMD_NAME(CMD_WRITE);
  CMD_NAME(CMD_UPDATE);
  CMD_NAME(CMD_CLEAR);
  CMD_NAME(TD_ADDCHANGEINT);
  CMD_NAME(TD_CHANGENUM);
  CMD_NAME(TD_CHANGESTATE);
  CMD_NAME(TD_EJECT);
  CMD_NAME(TD_FORMAT);
  CMD_NAME(TD_GETDRIVETYPE);
  CMD_NAME(TD_GETGEOMETRY);
  CMD_NAME(TD_MOTOR);
  CMD_NAME(TD_PROTSTATUS);
  CMD_NAME(TD_READ64);
  CMD_NAME(TD_REMCHANGEINT);
  CMD_NAME(TD_WRITE64);
  CMD_NAME(HD_SCSICMD);

  return "Unknown";
}

/* Execute the SD read or write command, return IOERR_* or TDERR_*
 */
LONG SD_ReadWrite(struct SDUnit *sdu, struct IORequest *io, ULONG off64, BOOL is_write)
{
  struct IOStdReq *iostd = (struct IOStdReq *)io;
  struct IOExtTD *iotd = (struct IOExtTD *)io;
  
  APTR data;
  ULONG len;
  ULONG block, block_size, bmask;
  UBYTE sderr;

  if (!sdu || !io) return 0;
  
  data = iotd->iotd_Req.io_Data;
  len = iotd->iotd_Req.io_Length;

  /*kprintf("%s: Flags: $%lx, Command: $%04lx, Offset: $%lx%08lx Length: %5ld, Data: $%08lx\n",
        is_write ? "write" : "read",
        io->io_Flags, io->io_Command,
        (ULONG)off64, (ULONG)off64, len, data);*/

  block_size = sdu->sdu_SDCmd.info.block_size;
  bmask = block_size - 1;

  if (!sdu->sdu_Valid) {
    //kprintf("TDERR_BadDriveType\n");
    return TDERR_BadDriveType;
  }
  
  if (sdu->sdu_ReadOnly) {
    //kprintf("TDERR_WriteProt\n");
    return TDERR_WriteProt;
  }
  
  if ((off64 & bmask) || bmask == 0 || data == NULL) {
    //kprintf("IOERR_BADADDRESS\n");
    return IOERR_BADADDRESS;
  }
  
  if ((len & bmask) || len == 0) {
    //kprintf("IO %lx Fault, io_Flags = %ld, io_Command = %ld, IOERR_BADLENGTH (len=0x%lx, bmask=0x%lx)\n", io, io->io_Flags, io->io_Command, len, bmask);
    return IOERR_BADLENGTH;
  }

  /* Make in units of sector size */
  len >>= 9;
  block = off64 >> 9;

  /* Nothing to do... */
  if (len < 1) {
    iostd->io_Actual = 0;
    return 0;
  }

  /* Do the IO */
  if (is_write) {
    sderr = sdcmd_write_blocks(&sdu->sdu_SDCmd, block, data, len);
  } else {
    sderr = sdcmd_read_blocks(&sdu->sdu_SDCmd, block, data, len);
  }

  if (sderr) {
    iostd->io_Actual = 0;

    /* Decode sderr into IORequest io_Errors */
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
  }
    
  iostd->io_Actual = len << 9; // * block_size
  return 0;
}

LONG SD_PerformSCSI(struct SDUnit* sdu, struct IORequest *io);

/*
 *  Try to do IO commands. All commands which require talking with ahci devices
 *  will be handled slow, that is they will be passed to bus task which will
 *  execute them as soon as hardware will be free.
 */
LONG SD_PerformIO(struct SDUnit *sdu, struct IORequest *io)
{
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  struct IOStdReq *iostd = (struct IOStdReq *)io;
  struct IOExtTD *iotd = (struct IOExtTD *)io;
  APTR data;
  ULONG len;
  ULONG off64;
  struct DriveGeometry *geom;
  LONG err = IOERR_NOCMD;
  int i;

  sdu = &SDBase->sd_Unit[0];
  
  debug("sdu: %lx io: %lx",sdu,io);
  
  if (!io) return 0;
  if (!sdu) return 0;
  if (!sdu->sdu_Enabled) {
    debug("");
    return 0;
  }

  data = iotd->iotd_Req.io_Data;
  len = iotd->iotd_Req.io_Length;

  if (io->io_Error == IOERR_ABORTED) {
    debug("IOERR_ABORTED\n");
    return io->io_Error;
  }

  debug("cmd: %s",cmd_name(io->io_Command));

  //debug("IO %lx Start, io_Flags = %ld, io_Command = %ld (%s)", io, io->io_Flags, io->io_Command, cmd_name(io->io_Command));
  
  switch (io->io_Command) {
  case CMD_CLEAR:     /* Invalidate read buffer */
    iostd->io_Actual = 0;
    err = 0;
    break;
  case CMD_UPDATE:    /* Flush write buffer */
    iostd->io_Actual = 0;
    err = 0;
    break;
  case TD_PROTSTATUS:
    iostd->io_Actual = sdu->sdu_ReadOnly ? 1 : 0;
    err = 0;
    break;
  case TD_CHANGENUM:
    iostd->io_Actual = sdu->sdu_ChangeNum;
    err = 0;
    break;
  case TD_REMOVE:
  case TD_CHANGESTATE:
    Forbid();
    iostd->io_Actual = sdu->sdu_Present ? 0 : 1;
    Permit();
    err = 0;
    break;
  case TD_EJECT:
    // Eject removable media
    // We mark is as invalid, then wait for Present to toggle.
    Forbid();
    sdu->sdu_Valid = FALSE;
    Permit();
    err = 0;
    break;
  case TD_GETDRIVETYPE:
    iostd->io_Actual = DG_DIRECT_ACCESS;
    err = 0;
    break;
  case TD_GETGEOMETRY:
    if (len < sizeof(struct DriveGeometry)) {
      err = IOERR_BADLENGTH;
      break;
    }

    geom = data;
    bzero(geom, sizeof(struct DriveGeometry));
    geom->dg_SectorSize   = sdu->sdu_SDCmd.info.block_size;
    geom->dg_TotalSectors = sdu->sdu_SDCmd.info.blocks;
    geom->dg_Cylinders    = sdu->sdu_SDCmd.info.blocks >> 10;
    geom->dg_CylSectors   = SD_HEADS * SD_SECTORS;
    geom->dg_Heads        = SD_HEADS;
    geom->dg_TrackSectors = SD_SECTORS;
    geom->dg_BufMemType   = MEMF_PUBLIC;
    geom->dg_DeviceType   = DG_DIRECT_ACCESS;
    geom->dg_Flags        = DGF_REMOVABLE;
    iostd->io_Actual = sizeof(struct DriveGeometry);
    err = 0;
    break;
  case TD_FORMAT:
    off64  = iotd->iotd_Req.io_Offset;
    err = SD_ReadWrite(sdu, io, off64, TRUE);
    break;
  case TD_MOTOR:
    iostd->io_Actual = sdu->sdu_Motor;
    sdu->sdu_Motor = iostd->io_Length ? 1 : 0;
    err = 0;
    break;
  case CMD_WRITE:
    off64  = iotd->iotd_Req.io_Offset;
    err = SD_ReadWrite(sdu, io, off64, TRUE);
    break;
  case TD_WRITE64:
    off64  = iotd->iotd_Req.io_Offset;
    //off64 |= ((ULONG)iotd->iotd_Req.io_Actual)<<32;
    err = SD_ReadWrite(sdu, io, off64, TRUE);
    break;
  case CMD_READ:
    off64  = iotd->iotd_Req.io_Offset;
    err = SD_ReadWrite(sdu, io, off64, FALSE);
    break;
  case TD_READ64:
    off64  = iotd->iotd_Req.io_Offset;
    //off64 |= ((ULONG)iotd->iotd_Req.io_Actual)<<32;
    err = SD_ReadWrite(sdu, io, off64, FALSE);
    break;
  case HD_SCSICMD:
    err = SD_PerformSCSI(sdu, io);
    break;
  default:
    debug("Unknown IO command: %ld", io->io_Command);
    err = IOERR_NOCMD;
    break;
  }

  //debug("io_Actual = %ld", iostd->io_Actual);
  debug("io_Error = %ld", err);
  return err;
}

LONG SD_PerformSCSI(struct SDUnit *sdu, struct IORequest *io)
{
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  struct IOStdReq *iostd = (struct IOStdReq *)io;
  struct SCSICmd *scsi = iostd->io_Data;
  struct sdcmd *sdc = &sdu->sdu_SDCmd;
  UBYTE *data = (UBYTE *)scsi->scsi_Data;
  ULONG i, block, blocks;
  LONG err;
  UBYTE r1;

  debug("SCSI len=%ld, cmd = %02lx %02lx %02lx ... (%ld)",
        iostd->io_Length, scsi->scsi_Command[0],
        scsi->scsi_Command[1], scsi->scsi_Command[2],
        scsi->scsi_CmdLength);
  if (iostd->io_Length < sizeof(struct SCSICmd)) {
    // RDPrep sends a bad io_Length sometimes
    //debug("====== BAD PROGRAM: iostd->io_Length < sizeof(struct SCSICmd)");
    return IOERR_BADLENGTH;
  }

  if (scsi->scsi_CmdLength < 6)
    return IOERR_BADLENGTH;

  if (scsi->scsi_Command == NULL)
    return IOERR_BADADDRESS;

  scsi->scsi_Actual = 0;

  switch (scsi->scsi_Command[0]) {
  case 0x00:      // TEST_UNIT_READY
    err = 0;
    break;
  case 0x12:      // INQUIRY
    for (i = 0; i < scsi->scsi_Length; i++) {
      UBYTE val;

      switch (i) {
      case 0: // direct-access device
        val = ((sdu->sdu_Enabled ? 0 : 1) << 5) | 0;
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
          val = "SD Card        "[i - 16];
        else if (i >= 32 && i < 36)
          val = "1.0  "[i-32]; // FIXME smelly ((UBYTE *)(((struct Library *)SDBase)->lib_IdString))
        else if (i >= 36 && i < 44) {
          val = sdc->info.cid[7 + ((i-36)>>1)];
          if ((i & 1) == 0)
            val >>= 4;
          val = "0123456789ABCDEF"[val & 0xf];
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
    //debug("READ (6) %ld @%ld => $%lx (%ld)",
    //      blocks, block, data, scsi->scsi_Length);
    if (block + blocks > sdc->info.blocks) {
      err = IOERR_BADADDRESS;
      break;
    }
    if (scsi->scsi_Length < (blocks << 9)) {
      //debug("Len (%ld) too small (%ld)", scsi->scsi_Length, blocks << 9);
      err = IOERR_BADLENGTH;
      break;
    }
    if (data == NULL) {
      err = IOERR_BADADDRESS;
      break;
    }
    r1 = sdcmd_read_blocks(sdc, block, data, blocks);
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
    /*debug("WRITE (6) %ld @%ld => $%lx (%ld)",
      blocks, block, data, scsi->scsi_Length);*/
    if (block + blocks > sdc->info.blocks) {
      err = IOERR_BADADDRESS;
      break;
    }
    if (scsi->scsi_Length < (blocks << 9)) {
      //debug("Len (%ld) too small (%ld)", scsi->scsi_Length, (blocks << 9));
      err = IOERR_BADLENGTH;
      break;
    }
    if (data == NULL) {
      err = IOERR_BADADDRESS;
      break;
    }
    r1 = sdcmd_write_blocks(sdc, block, data, blocks);
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
    
    block = scsi->scsi_Command[2];
    block = (block << 8) | scsi->scsi_Command[3];
    block = (block << 8) | scsi->scsi_Command[4];
    block = (block << 8) | scsi->scsi_Command[5];

    if ((scsi->scsi_Command[8] & 1) || block != 0) {
      // PMI Not supported
      err = HFERR_BadStatus;
      break;
    }

    if (scsi->scsi_Length < 8) {
      err = IOERR_BADLENGTH;
      break;
    }

    for (i = 0; i < 4; i++)
      data[0 + i] = (sdc->info.blocks >> (24 - (i<<3))) & 0xff;
    for (i = 0; i < 4; i++)
      data[4 + i] = (sdc->info.block_size >> (24 - (i<<3))) & 0xff;

    scsi->scsi_Actual = 8;
    err = 0;

    //debug("stop: blocks %ld block_size %ld",sdc->info.blocks,sdc->info.block_size);
    
    break;
  case 0x1a: // MODE SENSE (6)
    data[0] = 3 + 8 + 0x16;
    data[1] = 0; // MEDIUM TYPE
    data[2] = 0;
    data[3] = 8;
    if (sdc->info.blocks > (1 << 24))
      blocks = 0xffffff;
    else
      blocks = sdc->info.blocks;
    data[4] = (blocks >> 16) & 0xff;
    data[5] = (blocks >>  8) & 0xff;
    data[6] = (blocks >>  0) & 0xff;
    data[7] = 0;
    data[8] = 0;
    data[9] = 0;
    data[10] = (sdc->info.block_size >> 8) & 0xff;
    data[11] = (sdc->info.block_size >> 0) & 0xff;
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
          val = (SD_SECTORS >> 8) & 0xff;
          break;
        case 11: // SECTORS PER TRACK 7..0
          val = (SD_SECTORS >> 0) & 0xff;
          break;
        case 12: // DATA BYTES PER PHYSICAL SECTOR 15..8
          val = (sdc->info.block_size >> 8) & 0xff;
          break;
        case 13: // DATA BYTES PER PHYSICAL SECTOR 7..0
          val = (sdc->info.block_size >> 0) & 0xff;
          break;
        case 20: // HSEC = 1, RMB = 1
          val = (1 << 6) | (1 << 5);
          break;
        default:
          val = 0;
          break;
        }

        //debug("data[%2ld] = $%02lx", 12 + i, val);
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
          val = ((sdc->info.blocks >> 10) >> 16) & 0xff;
          break;
        case 3: // CYLINDERS 15..8
          val = ((sdc->info.blocks >> 10) >> 8) & 0xff;
          break;
        case 4: //  CYLINDERS 7..0
          val = ((sdc->info.blocks >> 10) >> 0) & 0xff;
          break;
        case 5: // HEADS
          val = SD_HEADS;
          break;
        default:
          val = 0;
          break;
        }

        data[12 + i] = val;
        //debug("data[%2ld] = $%02lx", 12 + i, val);
      }

      scsi->scsi_Actual = data[0] + 1;
      err = 0;
      break;
    default:
      debug("MODE SENSE: Unknown Page $%02lx.$%02lx",
            scsi->scsi_Command[2], scsi->scsi_Command[3]);
      err = HFERR_BadStatus;
      break;
    }
    break;
  default:
    debug("Unknown SCSI command %ld (%ld)\n", scsi->scsi_Command[0], scsi->scsi_CmdLength);
    err = IOERR_NOCMD;
    break;
  }

  if (err == 0)
    iostd->io_Actual = sizeof(*scsi);
  else
    iostd->io_Actual = 0;
    
  return err;
}



/*
void SD_IOTask() {
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  struct Task *this = FindTask(NULL);
  //struct SDUnit *sdu = &SDBase->sd_Unit[0];
  struct SDUnit *sdu = this->tc_UserData;
  struct MsgPort *mport = sdu->sdu_MsgPort;
  struct MsgPort *tport = NULL;
  struct timerequest *treq = NULL;
  ULONG sigset;
  struct Message status;

  //debug("SD_IOTask: sdus: %lx vs %lx",this->tc_UserData, &SDBase->sd_Unit[0]);

  status.mn_Length = 1;   // Failed?
  if ((status.mn_ReplyPort = CreateMsgPort())) {
    if ((tport = CreateMsgPort())) {
      if ((treq = (struct timerequest *)CreateIORequest(tport, sizeof(*treq)))) {
        if (0 == OpenDevice(TIMERNAME, UNIT_VBLANK, (struct IORequest *)treq, 0)) {
          status.mn_Length = 0;   // Success!
        } else {
          DeleteIORequest(treq);
        }
      } else {
        DeleteMsgPort(tport);
      }
    } else {
      DeleteMsgPort(status.mn_ReplyPort);
    }
  }

  debug("mport=%lx", mport);
  sdu->sdu_MsgPort = status.mn_ReplyPort;

  SD_Detect(sdu);
  
  //debug("sdu_MsgPort=%lx", sdu->sdu_MsgPort);
  PutMsg(mport, &status);

  //debug("ReplyPort=%lx%s empty", status.mn_ReplyPort, IsListEmpty(&status.mn_ReplyPort->mp_MsgList) ? "" : " not");
  if (status.mn_ReplyPort) {
    WaitPort(status.mn_ReplyPort);
    GetMsg(status.mn_ReplyPort);
  }

  if (status.mn_Length) {
    DeleteMsgPort(mport);
    return;
  }

  mport = sdu->sdu_MsgPort;
       
  sigset = (1 << tport->mp_SigBit) | (1 << mport->mp_SigBit);
  
  for (;;) {
    struct IORequest *io;

    //debug("task");

    SD_Detect(sdu);

    io = (struct IORequest *)GetMsg(mport);
    if (!io) {
      ULONG sigs;

      treq->tr_node.io_Command = TR_ADDREQUEST;
      treq->tr_time.tv_secs = 0;
      treq->tr_time.tv_micro = 100 * 1000;
      SendIO((struct IORequest *)treq);
      
      sigs = Wait(sigset);
      if (sigs & (1 << mport->mp_SigBit)) {
        io = (struct IORequest *)GetMsg(mport);
        AbortIO((struct IORequest *)treq);
      } else {
        io = NULL;
      }

      WaitIO((struct IORequest *)treq);
    }

    if (!io) continue;

    if (io->io_Command == 0xffff) {
      debug("KILL");
      io->io_Error = 0;
      io->io_Message.mn_Node.ln_Type=NT_MESSAGE;
      ReplyMsg(&io->io_Message);
      break;
      //continue;
    }

    //debug("");
    io->io_Error = SD_PerformIO(sdu, io);
    io->io_Message.mn_Node.ln_Type=NT_MESSAGE;

    ReplyMsg(&io->io_Message);
  }

  CloseDevice((struct IORequest *)treq);
  DeleteIORequest((struct IORequest *)treq);
  DeleteMsgPort(tport);
  DeleteMsgPort(mport);

  debug("leaving task");
  Wait(0);
}*/

#define PUSH(task, type, value) do {\
    struct Task *_task = task; \
    type _val = value; \
    _task->tc_SPReg -= sizeof(_val); \
    CopyMem(&_val, (APTR)_task->tc_SPReg, sizeof(_val)); \
} while (0)


#define NEWLIST(l) ((l)->lh_Head = (struct Node *)&(l)->lh_Tail, \
                    (l)->lh_TailPred = (struct Node *)&(l)->lh_Head)

void SD_InitUnit(struct SDBase* broken, int id)
{
  struct ExecBase* SysBase = *(struct ExecBase **)4L;
  struct SDUnit *sdu = &SDBase->sd_Unit[0];

  debug("init sdu: %lx",SDBase,sdu);

  switch (id) {
  case 0:
    sdu->sdu_SDCmd.iobase  = SD_BASE;
    sdu->sdu_Enabled = 1;
    break;
  default:
    sdu->sdu_Enabled = 0;
  }

  //sdu->sdu_SDCmd.func.log = SD_log;
  sdu->sdu_SDCmd.retry.read = SD_RETRY;
  sdu->sdu_SDCmd.retry.write = SD_RETRY;
  
  SD_Detect(sdu);

  /* If the unit is present, create an IO task for it
   */
  /*if (sdu->sdu_Enabled && !task_running) {
    struct Task *utask = &sdu->sdu_Task;
    struct MsgPort *initport;
    debug("-> enabled");
    task_running=1;

    if ((initport = CreateMsgPort())) {
      struct Message *msg;
      int i;
      
      sdu->sdu_Name[0] = 'S';
      sdu->sdu_Name[1] = 'D';
      sdu->sdu_Name[2] = 'I';
      sdu->sdu_Name[3] = 'O';
      sdu->sdu_Name[4] = '0';
      sdu->sdu_Name[4] += id;
      sdu->sdu_Name[5] = 0;
      
      sdu->sdu_MsgPort = initport;
      bzero(utask, 0, sizeof(*utask));
            
      utask->tc_Node.ln_Pri = -21;
      utask->tc_Node.ln_Name = &sdu->sdu_Name[0];
      utask->tc_SPReg = utask->tc_SPUpper = &sdu->sdu_Stack[SDU_STACK_SIZE];
      utask->tc_SPLower = &sdu->sdu_Stack[0];

      PUSH(utask, struct ExecBase*, SysBase);

      NEWLIST(&utask->tc_MemEntry);
      utask->tc_UserData = sdu;

      AddTask(utask, SD_IOTask, NULL);

      WaitPort(initport);
      msg = GetMsg(initport);
      if (msg->mn_Length==0) {
        sdu->sdu_Enabled = 1;
      } else {
        sdu->sdu_Enabled = 0;
      }
      ReplyMsg(msg);

      DeleteMsgPort(initport);
    } else {
      debug("-> failed CreateMsgPort()");
      sdu->sdu_Enabled = FALSE;
    }
  }*/

  // SDBase->sd_Unit[id].
  //("unit=%ld enabled=%ld", id, sdu->sdu_Enabled);
}


ADDTABL_END();
