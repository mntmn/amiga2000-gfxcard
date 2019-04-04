#ifndef SANA2_SANA2DEVICE_H
#define SANA2_SANA2DEVICE_H 1
/*
**      $Filename: devices/sana2.h $
**      $Revision: 4.1 $
**      $Date: 1994/10/03 20:55:10 $
**
**      Structure definitions for SANA-II devices.
**
**      (C) Copyright 1991 Commodore-Amiga Inc.
**              All Rights Reserved
*/


#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif

#ifndef EXEC_PORTS_H
#include <exec/ports.h>
#endif

#ifndef EXEC_IO_H
#include <exec/io.h>
#endif

#ifndef EXEC_ERRORS_H
#include <exec/errors.h>
#endif

#ifndef DEVICES_TIMER_H
#include <devices/timer.h>
#endif

#ifndef UTILITY_TAGITEM_H
#include <utility/tagitem.h>
#endif


#define SANA2_MAX_ADDR_BITS     (128)
#define SANA2_MAX_ADDR_BYTES    ((SANA2_MAX_ADDR_BITS+7)/8)

struct IOSana2Req
{
        struct IORequest ios2_Req;
        ULONG ios2_WireError;           /* wire type specific error     */
        ULONG ios2_PacketType;          /* packet type                  */
        UBYTE ios2_SrcAddr[SANA2_MAX_ADDR_BYTES];       /* source addr  */
        UBYTE ios2_DstAddr[SANA2_MAX_ADDR_BYTES];       /* dest address */
        ULONG ios2_DataLength;          /* length of packet data        */
        VOID *ios2_Data;                /* packet data                  */
        VOID *ios2_StatData;            /* statistics data pointer      */
        VOID *ios2_BufferManagement;    /* see SANA-II OpenDevice adoc  */
};


/*
** defines for the io_Flags field
*/
#define SANA2IOB_RAW    (7)             /* raw packet IO requested      */
#define SANA2IOF_RAW    (1<<SANA2IOB_RAW)

#define SANA2IOB_BCAST  (6)             /* broadcast packet (received)  */
#define SANA2IOF_BCAST  (1<<SANA2IOB_BCAST)

#define SANA2IOB_MCAST  (5)             /* multicast packet (received)  */
#define SANA2IOF_MCAST  (1<<SANA2IOB_MCAST)

#define SANA2IOB_QUICK  (IOB_QUICK)     /* quick IO requested (0)       */
#define SANA2IOF_QUICK  (IOF_QUICK)


/*
** defines for OpenDevice() flags
*/
#define SANA2OPB_MINE   (0)             /* exclusive access requested   */
#define SANA2OPF_MINE   (1<<SANA2OPB_MINE)

#define SANA2OPB_PROM   (1)             /* promiscuous mode requested   */
#define SANA2OPF_PROM   (1<<SANA2OPB_PROM)


/*
** defines for OpenDevice() tags
*/
#define S2_Dummy        (TAG_USER + 0xB0000)

#define S2_CopyToBuff   (S2_Dummy + 1)
#define S2_CopyFromBuff (S2_Dummy + 2)
#define S2_PacketFilter (S2_Dummy + 3)

struct Sana2DeviceQuery
{
/*
** Standard information
*/
        ULONG   SizeAvailable;          /* bytes available              */
        ULONG   SizeSupplied;           /* bytes supplied               */
        ULONG   DevQueryFormat;         /* this is type 0               */
        ULONG   DeviceLevel;            /* this document is level 0     */
/*
** Common information
*/
        UWORD   AddrFieldSize;          /* address size in bits         */
        ULONG   MTU;                    /* maximum packet data size     */
        ULONG   BPS;                    /* line rate (bits/sec)         */
        ULONG   HardwareType;           /* what the wire is             */
/*
** Format specific information
*/
};


/*
** defined Hardware types
**
**  If your hardware type isn't listed below contact CATS to get a new
**  type number added for your hardware.
*/
#define S2WireType_Ethernet             1
#define S2WireType_IEEE802              6
#define S2WireType_Arcnet               7
#define S2WireType_LocalTalk            11
#define S2WireType_DyLAN                12

#define S2WireType_AmokNet              200	/* Amiga Floppy Port hardware */

#define S2WireType_Liana		202	/* Villate Tronic parallel port hw */

#define S2WireType_PPP                  253
#define S2WireType_SLIP                 254
#define S2WireType_CSLIP                255	/* Compressed SLIP */

#define S2WireType_PLIP			420	/* SLIP over a parallel port */

struct Sana2PacketTypeStats
{
        ULONG PacketsSent;              /* transmitted count            */
        ULONG PacketsReceived;          /* received count               */
        ULONG BytesSent;                /* bytes transmitted count      */
        ULONG BytesReceived;            /* bytes received count         */
        ULONG PacketsDropped;           /* packets dropped count        */
};


struct Sana2SpecialStatRecord
{
        ULONG Type;                     /* statistic identifier         */
        ULONG Count;                    /* the statistic                */
        char *String;                   /* statistic name               */
};


struct Sana2SpecialStatHeader
{
        ULONG RecordCountMax;           /* room available               */
        ULONG RecordCountSupplied;      /* number supplied              */
        /* struct Sana2SpecialStatRecord[RecordCountMax]; */
};


struct Sana2DeviceStats
{
        ULONG PacketsReceived;          /* received count               */
        ULONG PacketsSent;              /* transmitted count            */
        ULONG BadData;                  /* bad packets received         */
        ULONG Overruns;                 /* hardware miss count          */
        ULONG Unused;                   /* Unused field                 */
        ULONG UnknownTypesReceived;     /* orphan count                 */
        ULONG Reconfigurations;         /* network reconfigurations     */
        struct timeval LastStart;       /* time of last online          */
};


/*
** Device Commands
*/
#define S2_START                (CMD_NONSTD)

#define S2_DEVICEQUERY          (S2_START+ 0)
#define S2_GETSTATIONADDRESS    (S2_START+ 1)
#define S2_CONFIGINTERFACE      (S2_START+ 2)
#define S2_ADDMULTICASTADDRESS  (S2_START+ 5)
#define S2_DELMULTICASTADDRESS  (S2_START+ 6)
#define S2_MULTICAST            (S2_START+ 7)
#define S2_BROADCAST            (S2_START+ 8)
#define S2_TRACKTYPE            (S2_START+ 9)
#define S2_UNTRACKTYPE          (S2_START+10)
#define S2_GETTYPESTATS         (S2_START+11)
#define S2_GETSPECIALSTATS      (S2_START+12)
#define S2_GETGLOBALSTATS       (S2_START+13)
#define S2_ONEVENT              (S2_START+14)
#define S2_READORPHAN           (S2_START+15)
#define S2_ONLINE               (S2_START+16)
#define S2_OFFLINE              (S2_START+17)

#define S2_END                  (S2_START+18)


/*
** defined errors for io_Error  (see also <exec/errors.h>)
*/
#define S2ERR_NO_ERROR          0       /* peachy-keen                  */
#define S2ERR_NO_RESOURCES      1       /* resource allocation failure  */
#define S2ERR_BAD_ARGUMENT      3       /* garbage somewhere            */
#define S2ERR_BAD_STATE         4       /* inappropriate state          */
#define S2ERR_BAD_ADDRESS       5       /* who?                         */
#define S2ERR_MTU_EXCEEDED      6       /* too much to chew             */
#define S2ERR_NOT_SUPPORTED     8       /* hardware can't support cmd   */
#define S2ERR_SOFTWARE          9       /* software error detected      */
#define S2ERR_OUTOFSERVICE      10      /* driver is OFFLINE            */
#define S2ERR_TX_FAILURE        11      /* Transmission attempt failed  */
/*
** From <exec/errors.h>
**
**      IOERR_OPENFAIL   (-1) * device/unit failed to open *
**      IOERR_ABORTED    (-2) * request terminated early [after AbortIO()] *
**      IOERR_NOCMD      (-3) * command not supported by device *
**      IOERR_BADLENGTH  (-4) * not a valid length (usually IO_LENGTH) *
**      IOERR_BADADDRESS (-5) * invalid address (misaligned or bad range) *
**      IOERR_UNITBUSY   (-6) * device opens ok, but requested unit is busy *
**      IOERR_SELFTEST   (-7) * hardware failed self-test *
*/

/*
** defined errors for ios2_WireError
*/
#define S2WERR_GENERIC_ERROR    0       /* no specific info available   */
#define S2WERR_NOT_CONFIGURED   1       /* unit not configured          */
#define S2WERR_UNIT_ONLINE      2       /* unit is currently online     */
#define S2WERR_UNIT_OFFLINE     3       /* unit is currently offline    */
#define S2WERR_ALREADY_TRACKED  4       /* protocol already tracked     */
#define S2WERR_NOT_TRACKED      5       /* protocol not tracked         */
#define S2WERR_BUFF_ERROR       6       /* buff mgt func returned error */
#define S2WERR_SRC_ADDRESS      7       /* source address problem       */
#define S2WERR_DST_ADDRESS      8       /* destination address problem  */
#define S2WERR_BAD_BROADCAST    9       /* broadcast address problem    */
#define S2WERR_BAD_MULTICAST    10      /* multicast address problem    */
#define S2WERR_MULTICAST_FULL   11      /* multicast address list full  */
#define S2WERR_BAD_EVENT        12      /* unsupported event class      */
#define S2WERR_BAD_STATDATA     13      /* statdata failed sanity check */
#define S2WERR_IS_CONFIGURED    15      /* attempt to config twice      */
#define S2WERR_NULL_POINTER     16      /* null pointer detected        */
#define S2WERR_TOO_MANY_RETIRES 17      /* tx failed - too many retries */
#define S2WERR_RCVREL_HDW_ERR   18      /* Driver fixable HW error      */


/*
** defined events
*/
#define S2EVENT_ERROR           (1L<<0) /* error catch all              */
#define S2EVENT_TX              (1L<<1) /* transmitter error catch all  */
#define S2EVENT_RX              (1L<<2) /* receiver error catch all     */
#define S2EVENT_ONLINE          (1L<<3) /* unit is in service           */
#define S2EVENT_OFFLINE         (1L<<4) /* unit is not in service       */
#define S2EVENT_BUFF            (1L<<5) /* buff mgt function error      */
#define S2EVENT_HARDWARE        (1L<<6) /* hardware error catch all     */
#define S2EVENT_SOFTWARE        (1L<<7) /* software error catch all     */


#endif  /* SANA2_SANA2DEVICE_H */
