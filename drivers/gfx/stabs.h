#ifndef _HEADERS_STABS_H
#define _HEADERS_STABS_H

/* These are some macros for handling of symboltable information
 */

/* linker can use symbol b for symbol a if a is not defined */
#define ALIAS(a,b) asm(".stabs \"_" #a "\",11,0,0,0;.stabs \"_" #b "\",1,0,0,0")

/* add symbol a to list b (type c (22=text 24=data 26=bss)) */
#define ADD2LIST(a,b,c) asm(".stabs \"_" #b "\"," #c ",0,0,_" #a )

/* Install private constructors and destructors pri MUST be -127<=pri<=127 */
#define ADD2INIT(a,pri) ADD2LIST(a,__INIT_LIST__,22); \
                        asm(".stabs \"___INIT_LIST__\",20,0,0," #pri "+128")
#define ADD2EXIT(a,pri) ADD2LIST(a,__EXIT_LIST__,22); \
                        asm(".stabs \"___EXIT_LIST__\",20,0,0," #pri "+128")

/* Add to library list */
#define ADD2LIB(a) ADD2LIST(a,__LIB_LIST__,24)

/* This one does not really handle symbol tables
 * it's just pointless to write a header file for one macro
 *
 * define a as a label for an absolute address b
 */
#define ABSDEF(a,b) asm("_" #a "=" #b ";.globl _" #a )

/* Generate assembler stub for a shared library entry
 * and add it to the jump table
 * ADDTABL_X(name,...)	means function with X arguments
 * ADDTABL_END()	ends the list
 * Usage: ADDTABL_2(AddHead,a0,a1);
 * No more than 4 arguments supported, use structures!
 */
 
#define _ADDTABL_START(name)		\
asm(".globl ___" #name);		\
asm("___" #name ":\tmovel a4,sp@-")

#define _ADDTABL_ARG(arg)		\
asm("\tmovel " #arg ",sp@-")

#define _ADDTABL_CALL(name)		\
asm("\tmovel a6@(40:W),a4");		\
asm("\tbsr _" #name)

#define _ADDTABL_END0(name,numargs)	\
asm("\tmovel sp@+,a4");			\
asm("\trts");				\
ADD2LIST(__##name,__FuncTable__,22)

#define _ADDTABL_END2(name,numargs)	\
asm("\taddqw #4*" #numargs ",sp");	\
asm("\tmovel sp@+,a4");			\
asm("\trts");				\
ADD2LIST(__##name,__FuncTable__,22)

#define _ADDTABL_ENDN(name,numargs)	\
asm("\taddaw #4*" #numargs ",sp");	\
asm("\tmovel sp@+,a4");			\
asm("\trts");				\
ADD2LIST(__##name,__FuncTable__,22)

#define ADDTABL_0(name)			\
_ADDTABL_START(name);			\
_ADDTABL_CALL(name);			\
_ADDTABL_END0(name,0)

#define ADDTABL_1(name,arg1)		\
_ADDTABL_START(name);			\
_ADDTABL_ARG(arg1);			\
_ADDTABL_CALL(name);			\
_ADDTABL_END2(name,1)

#define ADDTABL_2(name,arg1,arg2)	\
_ADDTABL_START(name);			\
_ADDTABL_ARG(arg2);			\
_ADDTABL_ARG(arg1);			\
_ADDTABL_CALL(name);			\
_ADDTABL_END2(name,2)

#define ADDTABL_3(name,arg1,arg2,arg3)	\
_ADDTABL_START(name);			\
_ADDTABL_ARG(arg3);			\
_ADDTABL_ARG(arg2);			\
_ADDTABL_ARG(arg1);			\
_ADDTABL_CALL(name);			\
_ADDTABL_ENDN(name,3)

#define ADDTABL_4(name,arg1,arg2,arg3,arg4) \
_ADDTABL_START(name);			\
_ADDTABL_ARG(arg4);			\
_ADDTABL_ARG(arg3);			\
_ADDTABL_ARG(arg2);			\
_ADDTABL_ARG(arg1);			\
_ADDTABL_CALL(name);			\
_ADDTABL_ENDN(name,4)

#define ADDTABL_END() asm(".stabs \"___FuncTable__\",20,0,0,-1")

#endif /* _HEADERS_STABS_H */
