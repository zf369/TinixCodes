; ==========================================
; sconst.inc
; kernel.asm中使用的常量
; ==========================================

; struct s_proc
; {
; 	STACK_FRAME    regs;
; 	t_16           ldt_sel;
; 	DESCRIPTOR     ldts[LDT_SIZE];
; } PROCESS;

P_STACKBASE	equ	0

; STACK_FRAME regs 结构体中各个成员的偏移地址
GSREG		equ	P_STACKBASE
FSREG		equ	GSREG		+ 4
ESREG		equ	FSREG		+ 4
DSREG		equ	ESREG		+ 4
EDIREG		equ	DSREG		+ 4
ESIREG		equ	EDIREG		+ 4
EBPREG		equ	ESIREG		+ 4
KERNELESPREG	equ	EBPREG		+ 4
EBXREG		equ	KERNELESPREG	+ 4
EDXREG		equ	EBXREG		+ 4
ECXREG		equ	EDXREG		+ 4
EAXREG		equ	ECXREG		+ 4
RETADR		equ	EAXREG		+ 4
EIPREG		equ	RETADR		+ 4
CSREG		equ	EIPREG		+ 4
EFLAGSREG	equ	CSREG		+ 4
ESPREG		equ	EFLAGSREG	+ 4
SSREG		equ	ESPREG		+ 4

P_STACKTOP	equ	SSREG		+ 4

; PROCESS 结构体中，STACK_FRAME后面就是LDT的选择子和LDT的描述符了
P_LDT_SEL	equ	P_STACKTOP        ; t_16 ldt_sel;
P_LDT		equ	P_LDT_SEL	+ 4   ; DESCRIPTOR ldts[LDT_SIZE];

; esp0 在TSS结构体中的偏移地址
TSS3_S_SP0	equ	4


; 以下选择子值必须与 protect.h 中保持一致!!!
; #define	SELECTOR_FLAT_C     0x08		// LOADER 里面已经确定了的.
; #define	SELECTOR_FLAT_RW    0x10		// 
; #define	SELECTOR_TSS        0x20        // TSS. 从外层跳到内层时 SS 和 ESP 的值从里面获得.

SELECTOR_FLAT_C    equ    0x08    ; LOADER 里面已经确定了的.
SELECTOR_TSS       equ    0x20    ; TSS. 从外层跳到内存时 SS 和 ESP 的值从里面获得.

SELECTOR_KERNEL_CS    equ    SELECTOR_FLAT_C
