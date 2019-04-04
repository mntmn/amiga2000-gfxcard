###############################################################################
#
# Common.mk 
#
# author: Henryk Richter <henryk.richter@gmx.net>
# 
# note: when switching between different hardware targets, don`t forget
#       "make clean" in between
#
# tools required:
#  GNU Make, either VBCC or GCC for AmigaOS/68k, VASM
#  recent sana2.h , e.g. from RoadShow SDK
#
# porting:
#  you might need to adapt the paths (prefix for Compiler/Includes)
#  Some installations have ADE: instead of GG: on Amigaos
#  Recent work on AmigaOS cross toolchains suggest /opt/m68k-amigaos/sys-include
#  instead of the traditional os-include
#
###############################################################################
# debug = 1 will include string debugging for terminal/sushi/sashimi
debug = 1
# compiler_vcc = 1 will trigger VBCC, else GCC
compiler_vcc = 1

###############################################################################
# prefix for system includes (ASM)
# native AmigaOS compilation: set PREFX=GG: or PREFX=ADE:, depending on toolchain
###############################################################################
PREFX  = /home/mntmn/code/vbcc/targets/m68k-amigaos
#PREFX = gg:
SYSINC = "-I$(PREFX)/include -I$(PREFX)/include2"

###############################################################################
#
# compiler executables (choice of gcc or vbcc)
# 
###############################################################################
ifeq ($(compiler_vcc),1)

# VBCC (use explicit vlink line for LINK= if complaints about R_PC happen)
CCX  = vc +aos68k $(SYSINC)
LINK = vlink -bamigahunk -x -s -mrel -Cvbcc -Bstatic -nostdlib #-Rshort 
#LINKEXE = vlink -bamigahunk -x -s -mrel -Cvbcc -Bstatic
LINKEXE = vc +aos68k
#LINK = $(CCX) -nostdlib
CFLAGS  = -Os -+ -sc -c99 -cpu=$(CPU)
CFLAGS2 = -Os -+ -sc -c99 -cpu=$(CPU2)

else

# GCC
CCX  = m68k-amigaos-gcc
LINK = $(CCX) -nostartfiles -s 
LINKEXE = $(CCX) -s -noixemul
CFLAGS  = -O3 -s -m$(CPU) -Wall -noixemul -mregparm=4 -fomit-frame-pointer -msoft-float -noixemul
CFLAGS2 = -O3 -s -m$(CPU2) -Wall -noixemul -mregparm=4 -fomit-frame-pointer -msoft-float -noixemul

endif

VASM = vasmm68k_mot
VASMFORMAT  = -m$(CPU) -Fhunk -nowarn=2064 -quiet $(SYSINC)
VASMFORMAT2 = -m$(CPU2) -Fhunk -nowarn=2064 -quiet $(SYSINC)

# unused here
#HOST = $(shell uname)

###############################################################################
#
# paths to the local includes 
# 
###############################################################################

IPATH =

###############################################################################
#
# compile-level feature definitions
# 
###############################################################################
ifeq ($(compiler_vcc),1)
# skip quotes with VCC, the AmigaOS native version doesn't like them
#DEFINES += -DDEVICEVERSION=$(DEVICEVERSION) -DDEVICEREVISION=$(DEVICEREVISION)
#DEFINES += -DDEVICEDATE=$(DEVICEDATE) 
#DEFINES += -DDEVICEEXTRA=$(DEVICEEXTRA)
DEFINES += -DDEVICENAME="$(DEVICEID)"
DEFINES += -DHAVE_VERSION_H=1
#DEFINES += -DNEWSTYLE
#ASMDEFS += -DDEVICEVERSION=$(DEVICEVERSION) -DDEVICEREVISION=$(DEVICEREVISION)
#ASMDEFS += -DDEVICEDATE=$(DEVICEDATE) -DDEVICENAME=$(DEVICEID)

#DEFINES2 += -DDEVICEVERSION=$(DEVICEVERSION) -DDEVICEREVISION=$(DEVICEREVISION)
#DEFINES2 += -DDEVICEDATE=$(DEVICEDATE) 
#DEFINES2 += -DDEVICEEXTRA=$(DEVICEEXTRA)
DEFINES2 += -DDEVICENAME="$(DEVICEID2)"
DEFINES2 += -DHAVE_VERSION_H=1
#DEFINES2 += -DNEWSTYLE
#ASMDEFS2 += -DDEVICEVERSION=$(DEVICEVERSION) -DDEVICEREVISION=$(DEVICEREVISION)

else

#DEFINES += -D"DEVICEVERSION=$(DEVICEVERSION)" -D"DEVICEREVISION=$(DEVICEREVISION)"
#DEFINES += -D"DEVICEDATE=$(DEVICEDATE)" 
#DEFINES += -D"DEVICEEXTRA=$(DEVICEEXTRA)"
DEFINES += -D"DEVICENAME="$(DEVICEID)""
DEFINES += -DHAVE_VERSION_H=1
DEFINES += -DNEWSTYLE
#ASMDEFS += -DDEVICEVERSION=$(DEVICEVERSION) -DDEVICEREVISION=$(DEVICEREVISION)
#ASMDEFS += -DDEVICEDATE=$(DEVICEDATE) -DDEVICENAME=$(DEVICEID)

#DEFINES2 += -D"DEVICEVERSION=$(DEVICEVERSION)" -D"DEVICEREVISION=$(DEVICEREVISION)"
#DEFINES2 += -D"DEVICEDATE=$(DEVICEDATE)" -D"DEVICENAME="$(DEVICEID2)""
#DEFINES2 += -D"DEVICEEXTRA=$(DEVICEEXTRA)"
DEFINES2 += -D"DEVICENAME="$(DEVICEID2)""
DEFINES2 += -DHAVE_VERSION_H=1
DEFINES2 += -DNEWSTYLE
#ASMDEFS2 += -DDEVICEVERSION=$(DEVICEVERSION) -DDEVICEREVISION=$(DEVICEREVISION)

endif


###############################################################################
#
# debug 
# 
###############################################################################
ifeq ($(debug),1)
CFLAGS  += -DDEBUG -g
CFLAGS2 += -DDEBUG -g
LINKLIBS = -L$(PREFX)/lib -ldebug -lamiga
endif

###############################################################################
#
# compiler flags and optimization levels
# 
###############################################################################

CFLAGS  += -I. -I$(SUBDIR)
CFLAGS2 += -I. -I$(SUBDIR)
LDFLAGS = 

###############################################################################
#
# objects to build 
# 
###############################################################################
# ASM based alternative to deviceheader.o would be romtag.o

OBJECTS = deviceheader.o deviceinit.o device.o 
OBJECTS += $(ASMOBJECTS)

# used for secondary build
OBJECTS2 = $(patsubst %.o,%.2o,$(OBJECTS))

###############################################################################
#
# rules and commands
# 
###############################################################################

all:	$(DEVICEID) $(DEVICEID2) $(TESTTOOL) $(TESTTOOL2)

clean:
	rm -f $(OBJECTS) $(OBJECTS2)
	rm -f $(DEVICEID) $(DEVICEID2) $(EXTRACLEAN)

# not for cross compile :-)
install: $(DEVICEID) $(DEVICEID2)
	copy $(DEVICEID) $(DEVICEID2) DEVS:


#sdnet:	 $(DEVICEID) 
#expnet: $(DEVICEID2)

$(DEVICEID) : $(OBJECTS)
	$(LINK) $(LDFLAGS) -o $@ $(OBJECTS) $(LINKLIBS) $(LINKOPTS)


# separate ruleset for each subdirectory, ./src overrides all other paths for priority
# of platform-optimized routines
%.o : %.c 
	$(CCX) -c $(CFLAGS) $(DEFINES) $(IPATH) $< -o $@

%.o : %.asm
	${VASM} $(VASMFORMAT) $(ASMDEFS) -o $@ $<


# secondary ruleset (used for expnet, will be ignored if DEVICEID2 is empty)
$(DEVICEID2) : $(OBJECTS2)
	$(LINK) $(LDFLAGS) -o $@ $(OBJECTS2) $(LINKLIBS) 

%.2o : %.c 
	$(CCX) -c $(CFLAGS2) $(DEFINES2) $(IPATH) $< -o $@

%.2o : %.asm
	${VASM} $(VASMFORMAT2) $(ASMDEFS2) -o $@ $<


