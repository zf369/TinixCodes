; ==========================================
; test.asm
; 简单测试CPL、RPL、DPL

; 修改了LABEL_DESC_DATA的DPL，改成了DA_DPL2
; 1. 修改了SelectorData，将RPL的优先级改成了SA_RPL1，这时候能正常运行。
; 2. 修改了SelectorData，将RPL的优先级改成了SA_RPL3，这时候不能正常运行。

; RPL保存在选择子的最低两位。 RPL 说明的是进程对段访问的请求权限，意思是当前进程想要的请求权限。
; RPL由程序员自己来自由的设置，并不一定RPL>=CPL，但是当RPL<CPL时，实际起作用的就是CPL了
; 因为访问时的特权检查是判断：EPL=max(RPL,CPL)<=DPL是否成立
; 所以RPL可以看成是每次访问时的附加限制，RPL=0时附加限制最小，RPL=3时附 加限制最大。
; 所以你不要想通过来随便设置一个rpl来访问一个比cpl更内层的段
; ==========================================

%include "pm.inc"  ; 常量, 宏, 以及一些说明

org    0100h
       jmp    LABEL_BEGIN     ; 接下来的是gdt数据部分，不是代码，必须要跳过去


; ===================   GDT   =======================

[SECTION .gdt]
; GDT
;                                     段基址                段界限    属性
LABEL_GDT:            Descriptor          0,                   0,    0        ; 空描述符
LABEL_DESC_NORMAL:	  Descriptor	      0,              0ffffh, DA_DRW	  ; Normal描述符，在16位代码段中，赋值给寄存器，重置告高速缓冲寄存器
LABEL_DESC_CODE32:    Descriptor          0,    SegCode32Len - 1, DA_C + DA_32 ; 非一致代码段, 32位代码段
LABEL_DESC_CODE16:    Descriptor          0,              0ffffh, DA_C         ; 非一致代码段, 16位代码段
LABEL_DESC_DATA:	  Descriptor	      0,	     DataLen - 1, DA_DRW + DA_DPL2  ; Data
LABEL_DESC_STACK:	  Descriptor	      0,          TopOfStack, DA_DRWA + DA_32	; Stack, 32 位
LABEL_DESC_LDT:       Descriptor          0,          LDTLen - 1, DA_LDT ; LDT
LABEL_DESC_VIDEO:     Descriptor    0B8000h,              0ffffh, DA_DRW ; 数据段，显存首地址

; 这里没有填充段基址，因为 段基址=[ds:offset]，现在ds还不知道，所以必须等代码运行以后，确定ds了才能填充

; GDT END

GdtLen        equ    $ - LABEL_GDT    ; GDT长度
GdtPtr        dw     GdtLen - 1       ; GDT界限=GdtLen-1？段界限=段内的最大偏移，从0开始。
              dd     0                ; GDT基地址，这个是暂时填0，后面ds确定了以后再填充

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT + SA_RPL1
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorLDT 		equ	LABEL_DESC_LDT		- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT

; END of [SECTION .gdt]


; ===================   数据段   =======================

[SECTION .data1]    ; 数据段

ALIGN    32
[BITS    32]

LABEL_DATA:

SPValueInRealMode    dw    0

PMMessage:      db    "In Protect Mode now. ^-^", 0  ; 进入保护模式以后显示该字符串
OffsetPMMessage     equ    (PMMessage - $$)

StrTest:		db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
OffsetStrTest		equ	   (StrTest - $$)

DataLen         equ    ($ - LABEL_DATA)

; END of [SECTION .data1]



; ===================   全局堆栈段   =======================
[SECTION .gs]

ALIGN    32
[BITS    32]

LABEL_STACK:
	; TODO: 现在堆栈是512B，测试一下将堆栈设置的特别小，call函数的时候是否会报错???
    ; 测试结果：栈不足，第一次call以后ret失败，程序无法继续
	times    512     db  0

TopOfStack    equ    ($ - LABEL_STACK - 1)

; END of [SECTION .gs]


; ===================   16位代码段   =======================

[SECTION .s16]    ; 16位代码段，实模式
[BITS  16]

LABEL_BEGIN:
        mov    ax, cs
        mov    ds, ax
        mov    es, ax
        mov    ss, ax
        mov    sp, 0100h       

        ; 将当前的cs填充到LABEL_GO_BACK_TO_REAL处，便于jmp回实模式
        mov [LABEL_GO_BACK_TO_REAL + 3], ax
        ; 保存sp到SPValueInRealMode处，回到实模式以后再读取回来
        mov [SPValueInRealMode], sp

        ; 填充16位代码段描述符的段基址
        mov    ax, cs
        movzx  eax, ax    ;movzx其实就是将我们的源操作数取出来,然后置于目的操作数,目的操作数其余位用0填充。
        shl    eax, 4
        add    eax, LABEL_SEG_CODE16  ; 段基址 = cs + offset？
        mov	   word [LABEL_DESC_CODE16 + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_CODE16 + 4], al
	    mov	   byte [LABEL_DESC_CODE16 + 7], ah

        ; 填充32位代码段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, cs
        shl    eax, 4
        add    eax, LABEL_SEG_CODE32  ; 段基址 = cs + offset？
        mov	   word [LABEL_DESC_CODE32 + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_CODE32 + 4], al
	    mov	   byte [LABEL_DESC_CODE32 + 7], ah

        ; 初始化数据段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_DATA  ; 段基址 = ds + offset？
        mov	   word [LABEL_DESC_DATA + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_DATA + 4], al
	    mov	   byte [LABEL_DESC_DATA + 7], ah

	    ; 初始化堆栈段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_STACK  ; 段基址 = ds + offset？
        mov	   word [LABEL_DESC_STACK + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_STACK + 4], al
	    mov	   byte [LABEL_DESC_STACK + 7], ah

        ; 初始化LDT描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_LDT  ; 段基址 = ds + offset？
        mov    word [LABEL_DESC_LDT + 2], ax
        shr    eax, 16
        mov    byte [LABEL_DESC_LDT + 4], al
        mov    byte [LABEL_DESC_LDT + 7], ah

        ; 初始化LDT中的LABEL_LDT_DESC_CODEA描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_CODE_A  ; 段基址 = ds + offset？
        mov    word [LABEL_LDT_DESC_CODEA + 2], ax
        shr    eax, 16
        mov    byte [LABEL_LDT_DESC_CODEA + 4], al
        mov    byte [LABEL_LDT_DESC_CODEA + 7], ah

	    ; 为加载 GDTR 作准备
	    xor	   eax, eax
	    mov	   ax, ds
	    shl	   eax, 4
	    add	   eax, LABEL_GDT		; eax <- gdt 基地址
	    mov	   dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	    ; 加载 GDTR
	    lgdt   [GdtPtr]

	    ; 关中断
	    cli

	    ; 打开地址线A20
	    in	   al, 92h       ; in al，92h 表示从92h号端口读入一个字节
	    or	   al, 00000010b
	    out	   92h, al       ; out 92h，al 表示向92h号端口写入一个字节

	    ; 准备切换到保护模式
	    mov    eax, cr0
	    or     eax, 1
	    mov    cr0, eax

	    ; 真正进入保护模式
	    jmp    dword SelectorCode32:0    ; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 SelectorCode32:0  处

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
		mov    ax, cs
        mov    ds, ax
        mov    es, ax
        mov    ss, ax

        ; 将保存在SPValueInRealMode处的sp恢复
        mov sp, [SPValueInRealMode]

        ; 关闭地址线A20
	    in	   al, 92h       ; ┓
	    and	   al, 11111101b ; ┣ 关闭 A20 地址线
	    out	   92h, al       ; ┛

	    ; 开中断
	    sti

	    ; 回到DOS
	    mov    ax, 4c00h    ; 4CH号功能——带返回码结束程序。AL=返回码
	    int    21h          ; INT 21是计算机中断的一种，不同的AH值表示不同的中断功能。

; END of [SECTION .s16]


; ===================   32位代码段   =======================

[SECTION .s32]    ; 32位代码段，由实模式跳入
[BITS  32]

LABEL_SEG_CODE32:
	    mov    ax, SelectorData
        mov    ds, ax          ; 数据段选择子->ds，保护模式的段地址都是Selector

        mov    ax, SelectorVideo
        mov    gs, ax          ; 视频段选择子(目的)

        mov    ax, SelectorStack
        mov    ss, ax          ; 堆栈段选择子

        mov    esp, TopOfStack ; esp 指向栈底


        ; 下面显示一个字符串
        mov    ah, 0Ch    ; 0000: 黑底    1100: 红字

        xor    esi, esi
        xor    edi, edi

        mov    esi, OffsetPMMessage      ; 将PMMessage字符串的offset写入esi
        mov    edi, (80 * 10 + 0) * 2    ; 目标是屏幕第 10 行, 第 0 列。

        cld    ; cld使DF 复位，即是让DF=0，std使DF置位，即DF=1.

.1:
        lodsb  ; 其中LODSB是读入AL,LODSW是读入AX中,然后SI自动增加或减小1或2位.

        test    al, al    ; TEST AX,BX 与 AND AX,BX 命令有相同效果
        jz      .2

        mov    [gs:edi], ax
        add    edi, 2

        jmp    .1

.2:     ; 显示PMMessage完毕

        call    DispReturn     ; 换行

        ; 载入LDT，这里是通过LDT的选择子加载，而不是像加载GDT一样使用[offset]，因为现在是保护模式了
        mov    ax, SelectorLDT
        lldt   ax        

        ; 跳转到LDT中的局部任务
        jmp    SelectorLDTCodeA:0

; ------------------------------------------------------------------------
; DispReturn: 模拟一个回车的显示（改变edi寄存器，让edi的值变成下一行的开头的值）
;   edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;   edi

; 其中edi始终指向要显示的下一个字符的位置。例如：
; mov    edi, (80 * 10 + 0) * 2    ; 屏幕第 10 行, 第 0 列。

; 80*25彩色字模式的显示显存在内存中的地址为B8000h~BFFFH,共32k.向这个地址写入的内容立即显示在屏幕上边.
; 在80*25彩色字模式 下共可以显示25行,每行80字符,每个字符在显存中占两个字节,第一个字节是字符的ASCII码.
; 第二字节是字符的属性，(80字符占160个字节）。
; ------------------------------------------------------------------------

DispReturn:
        push    eax
        push    ebx

        mov    eax, edi

        ; eax / 160 执行后al＝当前行号 
        mov    bl, 160
        div    bl         ;除数位数    隐含的被除数    商    余数    举例
                          ; 8位           AX        AL    AH    DIV  BH
                          ; 16位        DX-AX       AX    DX    DIV  BX
                          ; 32位       EDX-EAX     EAX   EDX    DIV  ECX

        and    eax, 0FFh  ; 只保留行号，列号清0，因为余数在AH中，而余数就是列号？？
        inc    eax        ; eax+＝1，使eax为当前行的下一行
        
        ; eax * 160，eax为当前行的下一行的开始
        mov    bl, 160
        mul    bl         ;乘数位数    隐含的被乘数    乘积的存放位置     举例
                          ; 8位         AL              AX          MUL  BL
                          ; 16位        AX             DX-AX        MUL  BX
                          ; 32位        EAX           EDX-EAX       MUL  ECX

        ; 使edi指向当前行的下一行的开始
        mov    edi, eax

        pop    ebx
        pop    eax

        ret
; DispReturn 结束---------------------------------------------------------

SegCode32Len    equ    ($ - LABEL_SEG_CODE32)

; END of [SECTION .s32]

; ------------------------------------------------------------------------
; 从保护模式跳转实模式前，需要加载一个合适的描述符选择子到有关的段寄存器，
; 以使对应段描述符高速缓冲寄存器中含有合适的段界限和属性
; 段界限显然是64K，即0ffffh(因为实模式下所有的段最大只能是16bit)，属性应该是DA_DRW，即可读写数据段
; 不能从32位代码段返回实模式，只能从16位代码段中返回。
; 因为无法实现从32位代码段返回时cs高速缓冲寄存器中的属性符合实模式的要求(实模式不能改变段属性)。

; 实模式下，段寄存器含有段值，处理器引用相应的某个段寄存器并将其值乘以16，形成20位的段基地址。
; 在保护模式下，段寄 存器含有段选择子，处理器要使用选择子所指定的描述符中的基地址等信息。
; 为了避免在每次存储器访问时，都要访问 描述符表而获得对应的段描述符，从80286开始每个段寄存器都配有一个高速缓冲寄存器，
; 称之为段描述符高速缓冲寄存器 或描述符投影寄存器，
; 对程序员而言 它是不可见的。每当把一个选择子装入到某个段寄存器时，处理器自动从描述符表中取出相应的描述符，
; 把描述符中的信息保存到对应的高速缓冲寄存器中。
; 此后对 该段访问时，处理器都使用对应高速缓冲寄存器中的描述符信息，而不用再从描述符表中取描述符。

; 新增的Normal描述符，段界限64K，属性DA_DRW，
; 在返回实模式之前把对应选择子SelectorNormal加载到ds、es和ss正好合适。

; ------------------------------------------------------------------------

; ===================   16位代码段   =======================

; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
; 不能从32位保护模式直接跳回实模式，需要先从32位代码段跳到16位代码段，设置寄存器，再跳回实模式

[SECTION .s16code]
ALIGN    32
[BITS    16]

LABEL_SEG_CODE16:
    ; 先将保护模式中使用的寄存器都使用SelectorNormal设置一下
    ; 好像是让高速寄存器含有合适的段界限和属性
    
    ; TODO: 测试一下不给寄存器设置SelectorNormal是否能返回实模式???
    ; 测试结果，不设置寄存器不能跳回到实模式
    mov    ax, SelectorNormal
    mov    ds, ax
    mov    es, ax
    mov    fs, ax
    mov    gs, ax
    mov    ss, ax
    
    mov    eax, cr0
    and    al, 11111110b
    mov    cr0, eax

LABEL_GO_BACK_TO_REAL:
    jmp    0:LABEL_REAL_ENTRY    ; 这里是跳回实模式，其实就是 jmp cs:offset
                                 ; 不过cs设置成0了，但是在97行代码处，将该处的0填充成了实模式下cs的值。


Code16Len    equ    ($ - LABEL_SEG_CODE16)

; END of [SECTION .s16code]


; ===================   LDT   =======================

[SECTION .ldt]
ALIGN    32

LABEL_LDT:
;                                     段基址                段界限    属性
LABEL_LDT_DESC_CODEA: Descriptor          0,        CodeALen - 1, DA_C + DA_32   ; 非一致代码段, 32位代码段
; LDT END

LDTLen    equ    ($ - LABEL_LDT)

; LDT选择子，LDT的选择子必须把TI位设为1，这样才是从LDT中查找描述符
SelectorLDTCodeA    equ LABEL_LDT_DESC_CODEA - LABEL_LDT + SA_TIL

; END of [SECTION .ldt]


; ===================   LDT，32位代码段   =======================
[SECTION .la]
ALIGN   32
[BITS   32]

LABEL_CODE_A:
        mov    ax, SelectorVideo
        mov    gs, ax          ; 视频段选择子(目的)

        ; 下面显示一个字符串
        mov    ah, 0Ch    ; 0000: 黑底    1100: 红字
        mov    al, 'F'
        mov    edi, (80 * 12 + 10) * 2    ; 目标是屏幕第 12 行, 第 10 列。

        mov    [gs:edi], ax

        ; 跳转到16位代码段
        jmp    SelectorCode16:0

CodeALen    equ    ($ - LABEL_CODE_A)

; END of [SECTION .la]