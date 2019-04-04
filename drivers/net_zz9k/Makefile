###############################################################################
#
# makefile for vbcc or gcc
#
# author: Henryk Richter <henryk.richter@gmx.net>
# 
# concept:
#
# tools required:
#  - vbcc, defaulting to m68k-amigaos
#  - vlink
#  (- vasm)
#
# porting:
#
#  see Common.mk
#
###############################################################################

###############################################################################
# Date, version, extra objects to build
# 
###############################################################################
DEVICEVERSION=1
DEVICEREVISION=95
DEVICEDATE=04.04.2019
#SUBDIR=enc624j6net
#ASMOBJECTS = $(SUBDIR)/enc624j6l.o $(SUBDIR)/intervaltimer.o kprintf.o

###############################################################################
# Devices to build (1 or 2, keep DEVICEID2 empty if only one build is desired)
#
###############################################################################

DEVICEID=test.device
DEFINES = #
ASMDEFS = #
CPU = 68020
TESTTOOL = test

DEVICEID2= #test.device_68000
DEFINES2 = # -DPROTO_V2EXPNET
ASMDEFS2 = # -DPROTO_V2EXPNET
CPU2 = #68000

# additional housekeeping
EXTRACLEAN=test.o

###############################################################################
# import generic ruleset
# 
###############################################################################
include Common.mk

$(TESTTOOL) : test.o
	$(LINKEXE) $(LDFLAGS) -o $@ test.o


