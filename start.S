.global _start
_start:
	b entry_reset
	b entry_undefined_instruction
	b entry_software_interrupt
	b entry_prefetch_abort
	b entry_data_abort
	b entry_not_used
	b entry_irq
	b entry_fiq

/*
	guess the default is just jump to the undefined instruction. Since no one has been to set to another value, all interrupt is disabled functionally.
*/
handler_undefined_instruction: 	.word 4 
handler_software_interrupt: 	.word 4
handler_prefetch_abort: 		.word 4
handler_data_abort: 			.word 4
handler_irq: 					.word 4
handler_fiq: 					.word 4

.macro storeR0
	sub sp, sp, #4
	stmfd sp!, {r0}
.endm

.macro restoreR0
	ldr r0, [r0]
	str r0, [sp, #4]
	ldmfd sp!, {r0, pc} 
.endm

entry_undefined_instruction:
	storeR0
	ldr r0, handler_undefined_instruction
	restoreR0

entry_software_interrupt:
	storeR0
	ldr r0, handler_software_interrupt
	restoreR0

entry_prefetch_abort:
 	storeR0
	ldr r0, handler_prefetch_abort
	restoreR0

entry_data_abort:
  	storeR0
	ldr r0, handler_data_abort
	restoreR0

entry_irq:
 	storeR0
	ldr r0, handler_irq
	restoreR0

entry_fiq:
 	storeR0
	ldr r0, handler_fiq
	restoreR0

/* These are defined in the linker script file, only the time linking we can know the tail address of the code, where bss segment starts.   */
.global _BSS_START
_BSS_START: 	.word 	0xdeadbeef

.global _BSS_END
_BSS_END: 		.word 	0xdeadbeef

#define WTCON 		0x53000000
#define INTMSK 		0x4A000008
#define INTSUBMSK 	0x4A00001C

#define LOCKTIME 	0x4c000000
#define MPLLCON 	0x4C000004
#define CLKDIVN 	0x4C000014
#define FCLK 		320000000
#define M_MDIV 		127
#define M_PDIV 		2
#define M_SDIV 		1

#define BWSCON 		0x48000000
#define BANKCON6 	0x4800001C
#define BANKCON7 	0x48000020
#define REFRESH 	0x48000024
#define BANKSIZE 	0x48000028
#define MRSRB6 		0x4800002C
#define MRSRB7 		0x48000030

#define ADDRESS_STACK_BASE 	0x33FF8000
#define ADDRESS_STACK_USER 	(ADDRESS_STACK_BASE - 0x3800)
#define ADDRESS_STACK_SVC 	(ADDRESS_STACK_BASE - 0x2800)
#define ADDRESS_STACK_UNDEF (ADDRESS_STACK_BASE - 0x2400)
#define ADDRESS_STACK_ABORT (ADDRESS_STACK_BASE - 0x2000)
#define ADDRESS_STACK_IRQ 	(ADDRESS_STACK_BASE - 0x1000)
#define ADDRESS_STACK_FIQ 	(ADDRESS_STACK_BASE - 0x0000)

#define MODE_USER 	0x10
#define MODE_FIQ 	0x11
#define MODE_IRQ 	0x12
#define MODE_SVC 	0x13
#define MODE_ABORT 	0x17
#define MODE_UNDEF 	0x1b
#define MODE_MASK 	0x1f
#define NOINT 		0xc0

#define GPBCON 		0x56000010
#define GPBDAT 		0x56000014
#define GPBUP 		0x5600001C

entry_reset:
	/*disable watch dog timer. */
	ldr r0, =WTCON
	mov r1, #0x0
	str r1, [r0]

	/*disable interrupts*/
	ldr r0, =INTMSK
	ldr r1, =0xFFFFFFFF
	str r1, [r0]
	
	/*disable sub-interrupts*/
	ldr r0, =INTSUBMSK
	ldr r1, =0x7FFF
	str r1, [r0]
	
	/* enable LED0 display */
	ldr r0, =GPBCON
	mov r1, #0x400  /* 1 << 10 */
	str r1, [r0]

	ldr r0, =GPBDAT
	ldr r1, =0x0
	str r1, [r0]

	/*reduce lock time, does not know its function for now. */
	ldr r0, =LOCKTIME
	ldr r1, =0xFFFFFF
	str r1, [r0]

	/*FCLK:HCLK:PCLK = 1:4:8*/
	ldr r0, =CLKDIVN
	ldr r1, =5   
	str r1, [r0]

	/*enter async mode. */
	mrc p15, 0, r0, c1, c0, 0
	orr r0, r0, #0xC0000000
	mcr p15, 0, r0, c1, c0, 0

	/*Fout = (MDIV + 8) * 12 / (PDIV + 2) / SDIV*/
	ldr r0, =MPLLCON
	ldr r1, =((M_MDIV << 12) + (M_PDIV << 4) + (M_SDIV))
	str r1, [r0]
	
	/*enable SDRAM on bank6, 64M, 32bit*/
	ldr r0, =BWSCON
	ldr r1, =(0x2 << 24)
	str r1, [r0]

	ldr r0, =BANKCON6
	ldr r1, =(3 << 15 + 0 << 2 + 1)
	str r1, [r0]

	ldr r0, =REFRESH
	ldr r1, =(1 << 23 + 0 << 22 + 1 << 20 + 1 << 18 + 489 << 0 + 2 << 16)
	str r1, [r0]

	ldr r0, =BANKSIZE
	ldr r1, =(1 << 0 + 1 << 4 + 1 << 5)
	str r1, [r0]

	ldr r0, =MRSRB6
	ldr r1, =0x20
	str r1, [r0]

	/*delay some time*/
	mov r0, #1000
1:
	subs r0, r0, #1
	bne  1b

	bl SetupStack 

	bl clearBSS

	b .

clearBSS:
	ldr r0, _BSS_START
	ldr r1, _BSS_END
	mov r2, #0
1:
	str r2, [r0]
	add r0, r0, #4
	cmp r0, r1
	ble 1b

	mov pc, lr

SetupStack:
	mrs r0, cpsr	
	bic r0, r0, #MODE_MASK
	orr r1, r0, #MODE_UNDEF|NOINT
	msr cpsr, r1
	ldr sp, =ADDRESS_STACK_UNDEF

	orr r1, r0, #MODE_ABORT|NOINT
	msr cpsr, r1
	ldr sp, =ADDRESS_STACK_ABORT

	orr r1, r0, #MODE_IRQ|NOINT
	msr cpsr, r1
	ldr sp, =ADDRESS_STACK_IRQ

	orr r1, r0, #MODE_FIQ|NOINT
	msr cpsr, r1
	ldr sp, =ADDRESS_STACK_FIQ

	bic r0, r0, #MODE_MASK|NOINT
	orr r1, r0, #MODE_SVC
	msr cpsr, r1
	ldr sp, =ADDRESS_STACK_SVC
	mov pc, lr
	
