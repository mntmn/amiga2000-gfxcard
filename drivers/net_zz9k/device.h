/*
  device.h

  (C) 2018 Henryk Richter <henryk.richter@gmx.net>

  Device Functions and Definitions


*/
#ifndef _INC_DEVICE_H
#define _INC_DEVICE_H

/* defaults */
#define MAX_UNITS 4

/* includes */
#include "compiler.h"
#include <dos/dos.h>
#include <exec/lists.h>
#include <exec/libraries.h>
#include <exec/devices.h>
#include <exec/semaphores.h>
#include "debug.h"
#include "sana2.h"

/* reassign Library bases from global definitions to own struct */
#define SysBase      db->db_SysBase
#define DOSBase      db->db_DOSBase
#define UtilityBase  db->db_UtilityBase

struct DevUnit {
	/* HW Data (generic for now) (example only, unused in construct)*/
	ULONG	du_hwl0;
	ULONG	du_hwl1;
	ULONG	du_hwl2;
	APTR	du_hwp0;
	APTR	du_hwp1;
	APTR	du_hwp2;
};


struct devbase {
	struct  Library db_Lib;
	BPTR 	db_SegList; /* from Device Init */

	ULONG		 db_Flags;   /* misc */
	struct Library	*db_SysBase; /* Exec Base */
        struct Library	*db_DOSBase;
	struct Library  *db_UtilityBase;

	struct DevUnit	db_Units[MAX_UNITS]; /* unused in construct */
};

#ifndef DEVBASETYPE
#define DEVBASETYPE struct devbase
#endif
#ifndef DEVBASEP
#define DEVBASEP DEVBASETYPE *db
#endif

/* PROTOS */

ASM LONG LibNull( void );

ASM SAVEDS struct Device *DevInit(ASMR(d0) DEVBASEP                  ASMREG(d0), 
                                  ASMR(a0) BPTR seglist              ASMREG(a0), 
				  ASMR(a6) struct Library *_SysBase  ASMREG(a6) );

ASM SAVEDS LONG DevOpen( ASMR(a1) struct IOSana2Req *ios2            ASMREG(a1), 
                         ASMR(d0) ULONG unit                         ASMREG(d0), 
                         ASMR(d1) ULONG flags                        ASMREG(d1),
                         ASMR(a6) DEVBASEP                           ASMREG(a6) );

ASM SAVEDS BPTR DevClose(   ASMR(a1) struct IORequest *ios2         ASMREG(a1),
                            ASMR(a6) DEVBASEP                        ASMREG(a6) );

ASM SAVEDS BPTR DevExpunge( ASMR(a6) DEVBASEP                        ASMREG(a6) );

ASM SAVEDS VOID DevBeginIO( ASMR(a1) struct IOSana2Req *ios2         ASMREG(a1),
                            ASMR(a6) DEVBASEP                        ASMREG(a6) );

ASM SAVEDS LONG DevAbortIO( ASMR(a1) struct IORequest *ios2         ASMREG(a1),
                            ASMR(a6) DEVBASEP                        ASMREG(a6) );

void dbTermIO( DEVBASETYPE*, struct IORequest * );

/* private functions */
#ifdef DEVICE_MAIN

//static void dbNewList( struct List * );
//static LONG dbIsInList( struct List *, struct Node * );

#endif /* DEVICE_MAIN */

#define HW_ADDRFIELDSIZE 6
#define HW_ETH_HDR_SIZE          14       /* ethernet header: dst, src, type */
#define HW_ETH_MTU               1500
const char HW_DEFAULT_MAC[] = {0xde,0xad,0xca,0xff,0xe2,0x42};

typedef BOOL (*BMFunc)(__reg("a0") void* a, __reg("a1") void* b, __reg("d0") long c);

typedef struct BufferManagement
{
  struct MinNode   bm_Node;
  BMFunc           bm_CopyFromBuffer;
  BMFunc           bm_CopyToBuffer;
} BufferManagement;

struct HWFrame {
   USHORT   hwf_Size;
   /* use layout of ethernet header here */
   UBYTE    hwf_DstAddr[HW_ADDRFIELDSIZE];
   UBYTE    hwf_SrcAddr[HW_ADDRFIELDSIZE];
   USHORT   hwf_Type;
   /*UBYTE    hwf_Data[MTU];*/
};

const struct InitTable
{
  ULONG LibBaseSize;
  APTR  FunctionTable;
  APTR  DataTable;
  APTR  InitLibTable;
};

#endif /* _INC_DEVICE_H */
