/*
  simple test for test.device

  calls CMD_READ, CMD_WRITE and prints contents of io_Error
  at each call (both should be 0 if device is working)

  (C) 2019 Henryk Richter <henryk.richter@gmx.net>

  compilation:
   m68k-amigaos-gcc test.c -noixemul
   sc test.c link

*/

#include <proto/dos.h>
#include <proto/exec.h>
#include <exec/io.h>
#include <exec/ports.h>


int main( int argc, char **argv )
{
	const char devname[] = "test.device";
	const unsigned long devunit = 0;
	struct MsgPort *mp = (0);
	struct IORequest *ior = (0);
	BYTE err = -1;

	do
	{
		mp = CreateMsgPort();
		if( !mp )
			break;
		ior = CreateIORequest( mp, sizeof(struct IOStdReq ) );
		if( !ior )
			break;
		err = OpenDevice( devname, devunit, ior, 0 );
		if( err )
			Printf("Error opening device\n");
		else	Printf("%s opened\n",devname);
	}
	while(0);

	/* do something with the device */
	if( !err )
	{
		ior->io_Command = CMD_WRITE;
		ior->io_Error = 10;
		DoIO( ior );
		Printf("io_Error after CMD_WRITE %d\n",ior->io_Error);

		ior->io_Command = CMD_WRITE;
		ior->io_Error = 12;
		DoIO( ior );
		Printf("io_Error after CMD_READ %d\n",ior->io_Error);
	}

	if( ior )
	{
		CloseDevice( ior );
		DeleteIORequest(ior);
	}
	if( mp )
		DeleteMsgPort(mp);
	

	return 0;
}
