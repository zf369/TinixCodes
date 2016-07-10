// ==========================================
// clock.c
// 时钟中断处理函数，进程调度算法在此
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proc.h"
#include "tty.h"
#include "console.h"
#include "global.h"
#include "string.h"
#include "proto.h"

/*======================================================================*
                            clock_handler
 *----------------------------------------------------------------------*
 * 作用：时钟中断处理函数，进程调度处理
 *======================================================================*/
PUBLIC void clock_handler(int irq)
{
	// disp_str("#");

	ticks++;  // 发生一次时钟中断，ticks+1

	p_proc_ready->ticks--;  // 当前执行的进程ticks--

	if (k_reenter != 0) 
	{
		// disp_str("!");
		return;
	}

	if (p_proc_ready->ticks > 0)
	{
		// 如果当前进程的ticks大于0，说明该进程还有时间片，继续执行，否则调度新的进程
		return;
	}
	
	schedule();
}

/*======================================================================*
                              milli_delay
 *----------------------------------------------------------------------*
 * 作用：通过ticks来实现delay
 *======================================================================*/
PUBLIC void milli_delay(int milli_sec)
{
	int t = get_ticks();

	while(((get_ticks() - t) * 1000 / HZ) < milli_sec) 
	{
		
	}
}

/*======================================================================*
                            init_clock
*----------------------------------------------------------------------*
 * 作用：初始化时钟中断处理函数，开启键盘中断
 *======================================================================*/
PUBLIC void init_clock()
{
	// **************************** 设置 8253 PIT ****************************
	out_byte(TIMER_MODE, RATE_GENERATOR);
	out_byte(TIMER0, (t_8) (TIMER_FREQ/HZ));
	out_byte(TIMER0, (t_8) ((TIMER_FREQ/HZ) >> 8));
	
	// **************************** 设置 时钟中断 处理函数 ****************************
	put_irq_handler(CLOCK_IRQ, clock_handler);
	enable_irq(CLOCK_IRQ); // 让8259A可以接收时钟中断
}

