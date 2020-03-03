/*
 * FreeRTOS Kernel V10.3.0
 * Copyright (C) 2020 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * http://www.FreeRTOS.org
 * http://aws.amazon.com/freertos
 *
 * 1 tab == 4 spaces!
 */


#ifndef PORTMACRO_H
#define PORTMACRO_H

#ifdef __cplusplus
extern "C" {
#endif

/*-----------------------------------------------------------
 * Port specific definitions.
 *
 * The settings in this file configure FreeRTOS correctly for the
 * given hardware and compiler.
 *
 * These settings should not be altered.
 *-----------------------------------------------------------
 */

/* Type definitions. */
#if __riscv_xlen == 64
	#define portSTACK_TYPE			uint64_t
	#define portBASE_TYPE			int64_t
	#define portUBASE_TYPE			uint64_t
	#define portMAX_DELAY 			( TickType_t ) 0xffffffffffffffffUL
	#define portPOINTER_SIZE_TYPE 	uint64_t
#elif __riscv_xlen == 32
	// #define portSTACK_TYPE	uint32_t
	// #define portBASE_TYPE	int32_t
	// #define portUBASE_TYPE	uint32_t
	#define portSTACK_TYPE	unsigned int
	#define portBASE_TYPE	int
	#define portUBASE_TYPE	unsigned int
	#define portMAX_DELAY ( TickType_t ) 0xffffffffUL
	#define portPOINTER_SIZE_TYPE 	uint32_t
#else
	#error Assembler did not define __riscv_xlen
#endif


typedef portSTACK_TYPE StackType_t;
typedef portBASE_TYPE BaseType_t;
typedef portUBASE_TYPE UBaseType_t;
typedef portUBASE_TYPE TickType_t;

/* Legacy type definitions. */
#define portCHAR		char
#define portFLOAT		float
#define portDOUBLE		double
#define portLONG		long
#define portSHORT		short

/* 32-bit tick type on a 32-bit architecture, so reads of the tick count do
not need to be guarded with a critical section. */
#define portTICK_TYPE_IS_ATOMIC 1
/*-----------------------------------------------------------*/

/* Architecture specifics. */
#define portSTACK_GROWTH			( -1 )
#define portTICK_PERIOD_MS			( ( TickType_t ) 1000 / configTICK_RATE_HZ )
#ifdef __riscv64
	#error This is the RV32 port that has not yet been adapted for 64.
	#define portBYTE_ALIGNMENT			16
#else
	#define portBYTE_ALIGNMENT			16
#endif
/*-----------------------------------------------------------*/


/* Scheduler utilities. */
extern void vTaskSwitchContext( void );
#define portYIELD() __asm volatile( "ecall" );
#define portEND_SWITCHING_ISR( xSwitchRequired ) if( xSwitchRequired ) vTaskSwitchContext()
#define portYIELD_FROM_ISR( x ) portEND_SWITCHING_ISR( x )
/*-----------------------------------------------------------*/


/* Critical section management. */
#define portCRITICAL_NESTING_IN_TCB					1
extern void vTaskEnterCritical( void );
extern void vTaskExitCritical( void );

#define portSET_INTERRUPT_MASK_FROM_ISR() 0
#define portCLEAR_INTERRUPT_MASK_FROM_ISR( uxSavedStatusValue ) ( void ) uxSavedStatusValue
#define portDISABLE_INTERRUPTS()	__asm volatile( "csrc sstatus, 2" )	//	__asm volatile( "csrc mstatus, 8" )
#define portENABLE_INTERRUPTS()		__asm volatile( "csrs sstatus, 2" )	//	__asm volatile( "csrs mstatus, 8" )
// #define portDISABLE_INTERRUPTS()
// #define portENABLE_INTERRUPTS()
// #define portENTER_CRITICAL()	vTaskEnterCritical()
// #define portEXIT_CRITICAL()		vTaskExitCritical()
//* modified by ljn
// #define portENTER_CRITICAL()	__asm volatile( "csrc sstatus, 2" )
// #define portEXIT_CRITICAL()		__asm volatile( "csrs sstatus, 2" )
#define portENTER_CRITICAL()
#define portEXIT_CRITICAL()
/*
#define portENTER_CRITICAL() {												\
	__asm volatile( "addi sp, sp, -8" );									\
	__asm volatile( "sw t0, 4(sp)" );										\
	__asm volatile( "li t0, 0x220" );										\
	__asm volatile( "csrc sie, t0" );										\
	__asm volatile( "lw t0, 4(sp)" );										\
	__asm volatile( "addi sp, sp, 8" );										\
}
#define portEXIT_CRITICAL() {												\
	__asm volatile( "addi sp, sp, -8" );									\
	__asm volatile( "sw t0, 4(sp)" );										\
	__asm volatile( "li t0, 0x220" );										\
	__asm volatile( "csrs sie, t0" );										\
	__asm volatile( "lw t0, 4(sp)" );										\
	__asm volatile( "addi sp, sp, 8" );										\
}*/
//*****************
/*-----------------------------------------------------------*/

/* Architecture specific optimisations. */
// #ifndef configUSE_PORT_OPTIMISED_TASK_SELECTION
// 	#define configUSE_PORT_OPTIMISED_TASK_SELECTION 1
// #endif

#if( configUSE_PORT_OPTIMISED_TASK_SELECTION == 1 )

// 	/* Check the configuration. */
// 	#if( configMAX_PRIORITIES > 32 )
// 		#error configUSE_PORT_OPTIMISED_TASK_SELECTION can only be set to 1 when configMAX_PRIORITIES is less than or equal to 32.  It is very rare that a system requires more than 10 to 15 difference priorities as tasks that share a priority will time slice.
// 	#endif

	/* Store/clear the ready priorities in a bit map. */
	#define portRECORD_READY_PRIORITY( uxPriority, uxReadyPriorities ) ( uxReadyPriorities ) |= ( 1UL << ( uxPriority ) )
	#define portRESET_READY_PRIORITY( uxPriority, uxReadyPriorities ) ( uxReadyPriorities ) &= ~( 1UL << ( uxPriority ) )

	/*-----------------------------------------------------------*/

	#define portGET_HIGHEST_PRIORITY( uxTopPriority, uxReadyPriorities ) uxTopPriority = ( 31UL - __builtin_clz( uxReadyPriorities ) )

#endif /* configUSE_PORT_OPTIMISED_TASK_SELECTION */


// /*-----------------------------------------------------------*/

// /* Task function macros as described on the FreeRTOS.org WEB site.  These are
// not necessary for to use this port.  They are defined so the common demo files
// (which build with all the ports) will build. */
// #define portTASK_FUNCTION_PROTO( vFunction, pvParameters ) void vFunction( void *pvParameters )
// #define portTASK_FUNCTION( vFunction, pvParameters ) void vFunction( void *pvParameters )

// /*-----------------------------------------------------------*/

// #define portNOP() __asm volatile 	( " nop " )

// #define portINLINE	__inline

// #ifndef portFORCE_INLINE
// 	#define portFORCE_INLINE inline __attribute__(( always_inline))
// #endif

// #define portMEMORY_BARRIER() __asm volatile( "" ::: "memory" )
// /*-----------------------------------------------------------*/


// /* configCLINT_BASE_ADDRESS is a legacy definition that was replaced by the
// configMTIME_BASE_ADDRESS and configMTIMECMP_BASE_ADDRESS definitions.  For
// backward compatibility derive the newer definitions from the old if the old
// definition is found. */
// #if defined( configCLINT_BASE_ADDRESS ) && !defined( configMTIME_BASE_ADDRESS ) && ( configCLINT_BASE_ADDRESS == 0 )
// 	/* Legacy case where configCLINT_BASE_ADDRESS was defined as 0 to indicate
// 	there was no CLINT.  Equivalent now is to set the MTIME and MTIMECMP
// 	addresses to 0. */
// 	#define configMTIME_BASE_ADDRESS 	( 0 )
// 	#define configMTIMECMP_BASE_ADDRESS ( 0 )
// #elif defined( configCLINT_BASE_ADDRESS ) && !defined( configMTIME_BASE_ADDRESS )
// 	/* Legacy case where configCLINT_BASE_ADDRESS was set to the base address of
// 	the CLINT.  Equivalent now is to derive the MTIME and MTIMECMP addresses
// 	from the CLINT address. */
// 	#define configMTIME_BASE_ADDRESS 	( ( configCLINT_BASE_ADDRESS ) + 0xBFF8UL )
// 	#define configMTIMECMP_BASE_ADDRESS ( ( configCLINT_BASE_ADDRESS ) + 0x4000UL )
// #elif !defined( configMTIME_BASE_ADDRESS ) || !defined( configMTIMECMP_BASE_ADDRESS )
// 	#error configMTIME_BASE_ADDRESS and configMTIMECMP_BASE_ADDRESS must be defined in FreeRTOSConfig.h.  Set them to zero if there is no MTIME (machine time) clock.  See https://www.freertos.org/Using-FreeRTOS-on-RISC-V.html
// #endif


//*	added by ljn
#define vPortStoreEnvironment(){														\
	__asm volatile( "li a1,0x20000004" );												\
	__asm volatile( "lw a2,0(a1)" );													\
	__asm volatile( "csrr a1,sepc " );													\
	__asm volatile( "sw a1,0(a2)" );													\
																						\
/*	__asm volatile( "sw x2,8(a2)" );													\
*/	__asm volatile( "sw x3,12(a2)" );													\
	__asm volatile( "sw x4,16(a2)" );													\
	__asm volatile( "sw x5,20(a2)" );													\
	__asm volatile( "sw x6,24(a2)" );													\
	__asm volatile( "sw x7,28(a2)" );													\
	__asm volatile( "sw x8,32(a2)" );													\
	__asm volatile( "sw x9,36(a2)" );													\
	__asm volatile( "sw x10,40(a2)" );													\
																						\
	__asm volatile( "sw x13,52(a2)" );													\
	__asm volatile( "sw x14,56(a2)" );													\
	__asm volatile( "sw x15,60(a2)" );													\
	__asm volatile( "sw x16,64(a2)" );													\
	__asm volatile( "sw x17,68(a2)" );													\
	__asm volatile( "sw x18,72(a2)" );													\
	__asm volatile( "sw x19,76(a2)" );													\
	__asm volatile( "sw x20,80(a2)" );													\
	__asm volatile( "sw x21,84(a2)" );													\
	__asm volatile( "sw x22,88(a2)" );													\
	__asm volatile( "sw x23,92(a2)" );													\
	__asm volatile( "sw x24,96(a2)" );													\
	__asm volatile( "sw x25,100(a2)" );													\
	__asm volatile( "sw x26,104(a2)" );													\
	__asm volatile( "sw x27,108(a2)" );													\
	__asm volatile( "sw x28,112(a2)" );													\
	__asm volatile( "sw x29,116(a2)" );													\
	__asm volatile( "sw x30,120(a2)" );													\
	__asm volatile( "sw x31,124(a2)" );													\
																						\
	__asm volatile( "li a1,0x20000008" );												\
	__asm volatile( "lw a3,0(a1)" );													\
	__asm volatile( "lw a4,4(a1)" );													\
	__asm volatile( "lw a5,8(a1)" );													\
	__asm volatile( "lw a6,12(a1)" );													\
	__asm volatile( "sw a3,4(a2)" );													\
	__asm volatile( "sw a4,44(a2)" );													\
	__asm volatile( "sw a5,48(a2)" );													\
	__asm volatile( "sw a6,8(a2)" );													\
}

#define vPortLoadEnvironment() {														\
	__asm volatile( "li a1,0x20000004" );												\
	__asm volatile( "lw a2,0(a1)" );													\
																						\
	__asm volatile( "lw x1,4(a2)" );													\
	__asm volatile( "lw x2,8(a2)" );													\
	__asm volatile( "lw x3,12(a2)" );													\
	__asm volatile( "lw x4,16(a2)" );													\
	__asm volatile( "lw x5,20(a2)" );													\
	__asm volatile( "lw x6,24(a2)" );													\
	__asm volatile( "lw x7,28(a2)" );													\
	__asm volatile( "lw x8,32(a2)" );													\
	__asm volatile( "lw x9,36(a2)" );													\
	__asm volatile( "lw x10,40(a2)" );													\
																						\
	__asm volatile( "lw x13,52(a2)" );													\
	__asm volatile( "lw x14,56(a2)" );													\
	__asm volatile( "lw x15,60(a2)" );													\
	__asm volatile( "lw x16,64(a2)" );													\
	__asm volatile( "lw x17,68(a2)" );													\
	__asm volatile( "lw x18,72(a2)" );													\
	__asm volatile( "lw x19,76(a2)" );													\
	__asm volatile( "lw x20,80(a2)" );													\
	__asm volatile( "lw x21,84(a2)" );													\
	__asm volatile( "lw x22,88(a2)" );													\
	__asm volatile( "lw x23,92(a2)" );													\
	__asm volatile( "lw x24,96(a2)" );													\
	__asm volatile( "lw x25,100(a2)" );													\
	__asm volatile( "lw x26,104(a2)" );													\
	__asm volatile( "lw x27,108(a2)" );													\
	__asm volatile( "lw x28,112(a2)" );													\
	__asm volatile( "lw x29,116(a2)" );													\
	__asm volatile( "lw x30,120(a2)" );													\
	__asm volatile( "lw x31,124(a2)" );													\
	__asm volatile( "lw a1,0(a2)" );													\
																						\
	__asm volatile( "csrw sepc,a1 " );													\
																						\
	__asm volatile( "lw x11,44(a2)" );													\
	__asm volatile( "lw x12,48(a2)" );													\
}

#define vPortReleaseSIE(){																\
	__asm volatile( "csrwi sip, 0" );													\
	__asm volatile( "sret" );															\
}

#define vPortStoreRA(){																	\
	__asm volatile( "addi sp,sp,-8" );													\
	__asm volatile( "sw ra, 4(sp)" );													\
}

#define vPortLoadRA(){																	\
	__asm volatile( "lw ra, 4(sp)" );													\
	__asm volatile( "addi sp,sp,8" );													\
}

#define vPortConfigureSIE(){															\
	__asm volatile( "addi sp,sp,-16" );													\
	__asm volatile( "sw ra,12(sp)" );													\
	__asm volatile( "sw a1,8(sp)" );													\
	__asm volatile( "sw a2,4(sp)" );													\
																						\
	__asm volatile( "lui a1,%hi(progForSIE)" );											\
	__asm volatile( "addi a2,a1,%lo(progForSIE)" );										\
	__asm volatile( "csrw stvec, a2" );													\
																						\
	__asm volatile( "lw a2,4(sp)" );													\
	__asm volatile( "lw a1,8(sp)" );													\
	__asm volatile( "lw ra,12(sp)" );													\
	__asm volatile( "addi sp,sp,16" );													\
	__asm volatile( "csrw sstatus,2" );													\
}

#ifdef __cplusplus
}
#endif

#endif /* PORTMACRO_H */

