/*
  device.c

  (C) 2018 Henryk Richter <henryk.richter@gmx.net>

  Device Functions

  the device core consists of three files, to be linked
  in the following order
  - deviceheader.c - ROMTAG
  - deviceinit.c   - strings and init tables
  - device.c       - functions
  I've had seen quite creative ways the different compilers
  handled the order of objects in the linked result and that's
  why I've chosen to break it down in the way you see here.

  The request handling and hardware interaction is carried out
  in server.c as a separate process. Interrupts are forwarded
  as signals to server.c as well (depending on target hardware).

  S2_CONFIGINTERFACE worked more than once, it *must* only work once.
  
*/
#define DEVICE_MAIN

#include <proto/exec.h>
#include <proto/utility.h>
#include <proto/dos.h>
#include <dos/dostags.h>
#include <utility/tagitem.h>
#include <exec/lists.h>
#include <exec/errors.h>
#include <string.h>
#ifdef HAVE_VERSION_H
#include "version.h"
#endif
/* NSD support is optional */
#ifdef NEWSTYLE
#include <devices/newstyle.h>
#endif /* NEWSTYLE */
#ifdef DEVICES_NEWSTYLE_H

const UWORD dev_supportedcmds[] = {
	NSCMD_DEVICEQUERY,
	CMD_READ,
	CMD_WRITE,
	/* ... add all cmds here that are supported by BeginIO */ 
	0
};

const struct NSDeviceQueryResult NSDQueryAnswer = {
	0,
	16, /* up to SupportedCommands (inclusive) TODO: correct number */
	NSDEVTYPE_SANA2, /* TODO: proper device type */
	0,  /* subtype */
	(UWORD*)dev_supportedcmds
};
#endif /* DEVICES_NEWSTYLE_H */

#include "device.h"
#include "macros.h"





ASM SAVEDS struct Device *DevInit( ASMR(d0) DEVBASEP                  ASMREG(d0), 
                                   ASMR(a0) BPTR seglist              ASMREG(a0), 
				   ASMR(a6) struct Library *_SysBase  ASMREG(a6) )
{
	UBYTE*p;
	ULONG i;
	LONG  ok;

	p = ((UBYTE*)db) + sizeof(struct Library);
	i = sizeof(DEVBASETYPE)-sizeof(struct Library);
	while( i-- )
		*p++ = 0;

	db->db_SysBase = _SysBase;
	db->db_SegList = seglist;
	db->db_Flags   = 0;

	ok = 0;
	if( (DOSBase = OpenLibrary("dos.library", 36)) )
	{
		if( (UtilityBase = OpenLibrary("utility.library", 37)) )
		{
			/* TODO: Search HW or initialize other stuff here */
			ok = 1;
			if( !ok )
			{
				D(("No Hardware\n"));
				CloseLibrary(DOSBase);
				CloseLibrary(UtilityBase);
			}
		}
		else
		{
			D(("No Utility\n"));
			CloseLibrary(DOSBase);
		}
	}
	else
	{
		D(("No DOS\n"));
	}

	/* no hardware found, reject init */
	return (ok > 0) ? (struct Device*)db : (0);
}




ASM SAVEDS LONG DevOpen( ASMR(a1) struct IOSana2Req *ioreq           ASMREG(a1), 
                         ASMR(d0) ULONG unit                         ASMREG(d0), 
                         ASMR(d1) ULONG flags                        ASMREG(d1),
                         ASMR(a6) DEVBASEP                           ASMREG(a6) )
{
	LONG ok,ret = IOERR_OPENFAIL;
  struct BufferManagement *bm;

	D(("DevOpen for %ld\n",unit));

	db->db_Lib.lib_OpenCnt++; /* avoid Expunge, see below for separate "unit" open count */

	/* TODO: some checks, if necessary */
	ok = 1;

  if (unit==0) {
    if ((bm = (struct BufferManagement*)AllocVec(sizeof(struct BufferManagement), MEMF_CLEAR|MEMF_PUBLIC))) {
      D(("ios2_bm: %lx\n",ioreq->ios2_BufferManagement));

      bm->bm_CopyToBuffer = (BMFunc)GetTagData(S2_CopyToBuff, 0, (struct TagItem *)ioreq->ios2_BufferManagement);
      bm->bm_CopyFromBuffer = (BMFunc)GetTagData(S2_CopyFromBuff, 0, (struct TagItem *)ioreq->ios2_BufferManagement);

      ioreq->ios2_BufferManagement = (VOID *)bm;
      ioreq->ios2_Req.io_Error = 0;
      ioreq->ios2_Req.io_Unit = (struct Unit *)unit; // not a real pointer, but id integer
      ioreq->ios2_Req.io_Device = (struct Device *)db;
    }
  }

	if( ok )
	{
		ret = 0;
	        db->db_Lib.lib_Flags &= ~LIBF_DELEXP;
    //ioreq->io_Error  = 0;
		//ioreq->io_Unit   = (struct Unit *)unit; /* my devices just carry the unit number instead of a pointer */
		//ioreq->io_Device = (struct Device *)db;
	}

	if( ret == IOERR_OPENFAIL )
	{
		ioreq->ios2_Req.io_Unit   = (0);
		ioreq->ios2_Req.io_Device = (0);
		ioreq->ios2_Req.io_Error  = ret;
		db->db_Lib.lib_OpenCnt--;
	}
	ioreq->ios2_Req.io_Message.mn_Node.ln_Type = NT_REPLYMSG;

	D(("DevOpen return code %ld\n",ret));

	return ret;
}


ASM SAVEDS BPTR DevClose(   ASMR(a1) struct IORequest *ioreq        ASMREG(a1),
                            ASMR(a6) DEVBASEP                       ASMREG(a6) )
{
	/* ULONG unit; */
	BPTR  ret = (0);

	D(("DevClose open count %ld\n",db->db_Lib.lib_OpenCnt));

	/* request valid ? */
	if( !ioreq )
		return ret;

	db->db_Lib.lib_OpenCnt--;

	ioreq->io_Device = (0);
	ioreq->io_Unit   = (struct Unit *)(-1);

	if (db->db_Lib.lib_Flags & LIBF_DELEXP)
		ret = DevExpunge(db);

	return ret;
}


ASM SAVEDS BPTR DevExpunge( ASMR(a6) DEVBASEP                        ASMREG(a6) )
{
	BPTR seglist = db->db_SegList;

	if( db->db_Lib.lib_OpenCnt )
	{
		db->db_Lib.lib_Flags |= LIBF_DELEXP;
		return (0);
	}
	
	Forbid();
	Remove((struct Node*)db); /* remove device node from system */
	Permit();

	/* last steps: libraries */
	CloseLibrary(DOSBase);
	CloseLibrary(UtilityBase);
	FreeMem( ((BYTE*)db)-db->db_Lib.lib_NegSize,(ULONG)(db->db_Lib.lib_PosSize + db->db_Lib.lib_NegSize));

	return seglist;
}

BOOL read_frame(struct IOSana2Req *req, UBYTE *frame);
ULONG write_frame(struct IOSana2Req *req, UBYTE *frame);

ASM SAVEDS VOID DevBeginIO( ASMR(a1) struct IOSana2Req *ioreq       ASMREG(a1),
                            ASMR(a6) DEVBASEP                       ASMREG(a6) )
{
	ULONG unit = (ULONG)ioreq->ios2_Req.io_Unit;

	ioreq->ios2_Req.io_Message.mn_Node.ln_Type = NT_MESSAGE;
  ioreq->ios2_Req.io_Error = S2ERR_NO_ERROR;
  ioreq->ios2_WireError = S2WERR_GENERIC_ERROR;

	//D(("BeginIO command %ld unit %ld\n",(LONG)ioreq->ios2_Req.io_Command,unit));

	switch( ioreq->ios2_Req.io_Command ) {
  case CMD_READ:
    //D(("Read command\n"));
    
    if (ioreq->ios2_BufferManagement == NULL) {
      ioreq->ios2_Req.io_Error = S2ERR_BAD_ARGUMENT;
      ioreq->ios2_WireError = S2WERR_BUFF_ERROR;
    }
    else {
      read_frame(ioreq, (UBYTE*)0x5eeffffc); // FIXME 0x5ef00000-4
      ioreq->ios2_Req.io_Error = 0;
    }
    break;
  case S2_BROADCAST:
    /* set broadcast addr: ff:ff:ff:ff:ff:ff */
    memset(ioreq->ios2_DstAddr, 0xff, HW_ADDRFIELDSIZE);
    /* fall through */
  case CMD_WRITE:
    write_frame(ioreq, (UBYTE*)0x5ef08000); // FIXME 0x5ef08000
    ioreq->ios2_Req.io_Error = 0;
    break;
  case S2_ONLINE:
  case S2_OFFLINE:
  case S2_CONFIGINTERFACE:   /* forward request */
    break;

  case S2_GETSTATIONADDRESS:
    memcpy(ioreq->ios2_SrcAddr, HW_DEFAULT_MAC, HW_ADDRFIELDSIZE); /* current */
    memcpy(ioreq->ios2_DstAddr, HW_DEFAULT_MAC, HW_ADDRFIELDSIZE); /* default */
    break;
  case S2_DEVICEQUERY:
    {
      struct Sana2DeviceQuery *devquery;

      devquery = ioreq->ios2_StatData;
      devquery->DevQueryFormat = 0;        /* "this is format 0" */
      devquery->DeviceLevel = 0;           /* "this spec defines level 0" */
         
      if (devquery->SizeAvailable >= 18) devquery->AddrFieldSize = HW_ADDRFIELDSIZE * 8; /* Bits! */
      if (devquery->SizeAvailable >= 22) devquery->MTU           = 1500;
      if (devquery->SizeAvailable >= 26) devquery->BPS           = 1000*1000*100;
      if (devquery->SizeAvailable >= 30) devquery->HardwareType  = S2WireType_Ethernet;

      devquery->SizeSupplied = (devquery->SizeAvailable<30?devquery->SizeAvailable:30);
    }
    break;
  case S2_GETSPECIALSTATS:
    {
      struct Sana2SpecialStatHeader *s2ssh = (struct Sana2SpecialStatHeader *)ioreq->ios2_StatData;
      s2ssh->RecordCountSupplied = 0;
    }
    break;
	}

	if( ioreq )
		dbTermIO( db, (struct IORequest*)ioreq );
}


ASM SAVEDS LONG DevAbortIO( ASMR(a1) struct IORequest *ioreq        ASMREG(a1),
                            ASMR(a6) DEVBASEP                       ASMREG(a6) )
{
	LONG   ret = 0;

	D(("AbortIO on %lx\n",(ULONG)ioreq));
	ioreq->io_Error = IOERR_ABORTED;

	ReplyMsg((struct Message*)ioreq);
	return ret;
}


void dbTermIO( DEVBASEP, struct IORequest *ioreq )
{
	//D(("dbTermIO flags %ld\n",(LONG)ioreq->io_Flags));

	ioreq->io_Message.mn_Node.ln_Type = NT_REPLYMSG;
	ReplyMsg( (struct Message *)ioreq );
}


/* private functions */
#if 0
static void dbForwardIO( DEVBASEP, struct IOSana2Req *ioreq )
{
	ioreq->ios2_Req.io_Flags &= ~SANA2IOF_QUICK;
	PutMsg(db->db_ServerPort, (struct Message*)ioreq);

	D(("Forward Request %ld\n",ioreq->ios2_Req.io_Command));
}

static void dbNewList( struct List *l )
{
  l->lh_TailPred = (struct Node *)l;
  l->lh_Head = (struct Node *)&l->lh_Tail; 
  l->lh_Tail = 0;
}

static LONG dbIsInList( struct List *l, struct Node *entry )
{
 struct Node *nd;

 nd = GetHead( l );
 while( nd )
 {
	if( nd == entry ) 
		return 1;

	nd = GetSucc(nd);
 }

 return 0;
}
#endif

static ULONG last_serial = 0;

BOOL read_frame(struct IOSana2Req *req, UBYTE *frame)
{
  LONG datasize;
  BYTE *frame_ptr;
  BOOL ok, broadcast;
  struct BufferManagement *bm;

  UBYTE* frm = (UBYTE*)frame;
  ULONG sz = ((ULONG)frm[0]<<8)|((ULONG)frm[1]);
  ULONG ser = ((ULONG)frm[2]<<8)|((ULONG)frm[3]);
  ULONG tp = ((ULONG)frm[16]<<8)|((ULONG)frm[17]);

  if (ser==last_serial) sz=0;
  last_serial = ser;

  if (sz>0) {
    D(("RXSZ %lx\n",sz));
    //D(("RXDST %lx...\n",*((ULONG*)(frm+2))));
    //D(("RXSRC %lx...\n",*((ULONG*)(frm+6))));
  }
  
  if (req->ios2_Req.io_Flags & SANA2IOF_RAW) {
    frame_ptr = frm+4;
    datasize = sz;
    req->ios2_Req.io_Flags = SANA2IOF_RAW;
  }
  else {
    frame_ptr = frm+4+HW_ETH_HDR_SIZE;
    datasize = sz-HW_ETH_HDR_SIZE;
    req->ios2_Req.io_Flags = 0;
  }

  req->ios2_DataLength = datasize;

  /* copy packet buffer */
  bm = (struct BufferManagement *)req->ios2_BufferManagement;
  if (!(*bm->bm_CopyToBuffer)(req->ios2_Data, frame_ptr, datasize)) {
    req->ios2_Req.io_Error = S2ERR_SOFTWARE;
    req->ios2_WireError = S2WERR_BUFF_ERROR;
    ok = FALSE;
  }
  else {
    req->ios2_Req.io_Error = req->ios2_WireError = 0;
    ok = TRUE;
  }
  
  memcpy(req->ios2_SrcAddr, frame+2+6, HW_ADDRFIELDSIZE);
  memcpy(req->ios2_DstAddr, frame+2, HW_ADDRFIELDSIZE);

  broadcast = TRUE;
  for (int i=0;i<HW_ADDRFIELDSIZE;i++) {
    if (frame[i+4] != 0xff) {
      broadcast = FALSE;
      break;
    }
  }
  if (broadcast) {
    req->ios2_Req.io_Flags |= SANA2IOF_BCAST;
  }
  
  req->ios2_PacketType = tp;

  return ok;
}

ULONG write_frame(struct IOSana2Req *req, UBYTE *frame)
{
   ULONG rc;
   struct BufferManagement *bm;
   USHORT sz=0;
   
   if (req->ios2_Req.io_Flags & SANA2IOF_RAW) {
      sz = req->ios2_DataLength;
   } else {
      sz = req->ios2_DataLength + HW_ETH_HDR_SIZE;
      *((USHORT*)(frame+6+6)) = (USHORT)req->ios2_PacketType;
      memcpy(frame, req->ios2_DstAddr, HW_ADDRFIELDSIZE);
      memcpy(frame+6, HW_DEFAULT_MAC, HW_ADDRFIELDSIZE);
      frame+=HW_ETH_HDR_SIZE;
   }

   if (sz>0) {
     bm = (struct BufferManagement *)req->ios2_BufferManagement;

     if (!(*bm->bm_CopyFromBuffer)(frame, req->ios2_Data, req->ios2_DataLength)) {
       rc = 1; // FIXME error code
     }
     else {
       // buffer was copied to zz9000, send it
       volatile USHORT* reg = (volatile USHORT*)(0x50000000+0x80); // FIXME
       *reg = sz;
     }
   }

   return rc;
}
