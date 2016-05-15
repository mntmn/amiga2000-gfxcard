
#define SD_BASE 0x8f0000

#define uint32 unsigned long
#define uint8 unsigned char
#define uint16 unsigned short

uint16 sdcmd_read_blocks(void* cmd, uint32 block, uint8* data, uint32 len);
uint16 sdcmd_write_blocks(void* cmd, uint32 block, uint8* data, uint32 len);
uint16 sdcmd_present();
uint16 sdcmd_detect();


#define SDERRF_TIMEOUT  (1 << 7)
#define SDERRF_PARAM    (1 << 6)
#define SDERRF_ADDRESS  (1 << 5)
#define SDERRF_ERASESEQ (1 << 4)
#define SDERRF_CRC      (1 << 3)
#define SDERRF_ILLEGAL  (1 << 2)
#define SDERRF_ERASERES (1 << 1)
#define SDERRF_IDLE     (1 << 0)

#define SD_UNITS    1       /* Only one chip select for now */

#define SDU_STACK_SIZE  (4096 / sizeof(ULONG))

struct sdcmd {
    struct Node *owner; /* Owner of this structure */

    ULONG iobase;

    struct sdcmd_retry {
        LONG read;      /* Number of retries to read a block */
        LONG write;     /* Number of retries to write a block */
    } retry;

    struct sdcmd_info {
        /* Raw OCR, CSD and CID data */
        ULONG ocr;
        UBYTE csd[16];
        UBYTE cid[16];

        /* Disk-like interface */
        ULONG block_size;
        ULONG blocks;
        BOOL  read_only;

        /* Conversion from block to SD address */
        UBYTE addr_shift;
    } info;

    /** Functions to be provided by the caller **/
    struct sdcmd_func {
        /* Add to the debug log.
         */
//        VOID (*log)(struct sdcmd *sd, int level, const char *format, ...);
    } func;
};

struct SDBase {
    struct Device*      sd_Device;
    struct Library*     sd_ExecBase;
    APTR                sd_SegList;
    struct SDUnit {
        struct Unit sdu_Unit;
        struct Task sdu_Task;
        TEXT        sdu_Name[6];                /* "SDIOx" */
        ULONG       sdu_Stack[SDU_STACK_SIZE];          /* 4K stack */
        BOOL        sdu_Enabled;

        struct sdcmd sdu_SDCmd;
        struct MsgPort *sdu_MsgPort;

        BOOL sdu_Present;               /* Is a device detected? */
        BOOL sdu_Valid;                 /* Is the device ready for IO? */
        BOOL sdu_ReadOnly;              /* Is the device read-only? */
        BOOL sdu_Motor;                 /* TD_MOTOR state */
        ULONG sdu_ChangeNum;

        struct Library *sdu_ExecBase;
    } sd_Unit[SD_UNITS];
};
