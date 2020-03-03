/*
 * Main function of FreeRTOS_on_Tuman32
 * Hardware ISA is based on RV-32I, OS Kernel is based on FreeRTOS V10.3.0
 * Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>. All Rights Reserved.
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
 * https://github.com/JunnanLi/iCore
 *
 * 1 tab == 4 spaces!
 */

//*	header files
#include "include/firmware.h"
#include "include/list.h"
#include "include/task.h"
#include "include/queue.h"
#include "include/semphr.h"
#include "include/string.h"

#define TEST_1 1	//multiple tasks with vTaskDelay, vTaskSuspend and vTaskAsume
// #define TEST_2 1	//multiple tasks with queue, semphr, countsem and MuxSem
#ifdef TEST_2
	#define TEST_QUEUE 1
	// #define TEST_SEMPHR 1
	// #define TEST_COUNTSEM 1
	// #define TEST_MUXSEM 1
#endif
/*------------------------------------------------------------------------*/
//* common part for main function (keey these for all tests) 

//* extern variable
extern List_t pxReadyTasksLists[ configMAX_PRIORITIES ];
extern TCB_t *pxCurrentTCB;

//* task variable
TaskHandle_t Task1_Handle;
#define TASK1_STACK_SIZE 128
StackType_t Task1Stack[TASK1_STACK_SIZE];
TCB_t Task1TCB;

TaskHandle_t Task2_Handle;
#define TASK2_STACK_SIZE 128
StackType_t Task2Stack[TASK2_STACK_SIZE];
TCB_t Task2TCB;

StackType_t IdleTaskStack[configMINIMAL_STACK_SIZE];
TCB_t IdleTaskTCB;

//*	functions for interrupt/exception
void schedulerForSsie(void){	//* Supervisor software interrupt/execption
	vPortStoreEnvironment();	//*	store current task's state;
	vTaskSwitchContext();		//*	switch to another task;
	//* store pxCurrentTCB->pxTopOfStack in TEMP_M0 (i.e., 0x20000004);
	*((uint32_t *)TEMP_M0) = (uint32_t) (pxCurrentTCB->pxTopOfStack);	
	vPortLoadEnvironment();		//*	reload everoment for another task;
	vPortReleaseSIE();			//* release software interrupt/exception;
}

void schedulerForStie(void){	//* Supervisor time interrupt/execption
	vPortStoreEnvironment();	//* store current task's state;
	print_str("**** + one clk ****\n");	//*	after one clock; i.e., 
								//*	define configCPU_CLOCK_HZ/configTICK_RATE_HZ;
	xTaskIncrementTick();		//* check program for time interrupt/execption,
								//*	e.g., wake the delayed task;
	vTaskSwitchContext();		//*	switch to another task;
	//* store pxCurrentTCB->pxTopOfStack in TEMP_M0 (i.e., 0x20000004);
	*((uint32_t *)TEMP_M0) = (uint32_t) (pxCurrentTCB->pxTopOfStack);
	vPortReleaseTIE();			//*	release time interrupt/exception;
	//*	load Environment
	vPortLoadEnvironment();		//*	reload everoment for another task;
	__asm volatile( "sret" );	//* finish time interrupt/exception;
	__asm volatile( "ebreak" );	//* Should not reach here as if "sret" is running;
}

void prvIdleTask( void );
void Task1_Entry( void );
void Task2_Entry( void );
void vApplicationGetIdleTaskMemory( TCB_t **ppxIdleTaskTCBBuffer,
									StackType_t **ppxIdleTaskStackBuffer,
									uint32_t *pulIdleTaskStackSize );


void prvIdleTask( void ){		//* idle task;
	uint32_t parameter;
	prvTaskIdleTask((void*) &parameter);
	// while(1){
	// 	// print_str("idleTask\n");
	// }
}

void vApplicationGetIdleTaskMemory( TCB_t **ppxIdleTaskTCBBuffer,
									StackType_t **ppxIdleTaskStackBuffer,
									uint32_t *pulIdleTaskStackSize )
{
	*ppxIdleTaskTCBBuffer=&IdleTaskTCB;
	*ppxIdleTaskStackBuffer=IdleTaskStack;
	*pulIdleTaskStackSize=configMINIMAL_STACK_SIZE;
}
//*	End of common part;
/*------------------------------------------------------------------------*/


/*------------------------------------------------------------------------*/
//*	test 1: multiple tasks with vTaskDelay, vTaskSuspend and vTaskAsume
#ifdef TEST_1
	TCB_t *pxSuspendedTCB;

	//*	main funciton
	void mainFreeRTOS(void){
		//* creat task
		Task1_Handle =
			xTaskCreateStatic( 
			(TaskFunction_t)Task1_Entry,	//* task entry (function name)
			(const char *)"Task1",			//* task name
			(uint32_t)TASK1_STACK_SIZE,		//* stack size of task, in word
			(void *) NULL,					//* function parameter
			1,								//* uxPriority
			(StackType_t *)Task1Stack,		//* stack addr of task
			(StaticTask_t *)&Task1TCB );	//* task block

		Task2_Handle =
			xTaskCreateStatic( 
			(TaskFunction_t)Task2_Entry,	//* task entry (function name)
			(const char *)"Task2",			//* task name
			(uint32_t)TASK2_STACK_SIZE,		//* stack size of task, in word
			(void *) NULL,					//* function parameter
			2,								//* uxPriority
			(StackType_t *)Task2Stack,		//* stack addr of task
			(StaticTask_t *)&Task2TCB );	//* task block

		vPortConfigureSIE();				//*	preparation for SIE
		vTaskStartScheduler();				//*	start scheduling
	}

	//* task 1
	void Task1_Entry( void ){
		while(1){
			print_str("task1-0\n");	
			
			if(pxSuspendedTCB != NULL){
				vTaskResume(pxSuspendedTCB);//* test for vTaskResume
				pxSuspendedTCB = NULL;
			}

			// vTaskDelete(Task1_Handle);	//*	test for vTaskDelete

			print_str("task1-1\n");	
			vTaskDelay( 2 );				//*	test for vTaskDelay

			print_str("task1-2\n");
			vTaskDelay( 2 );
			
			print_str("task1-3\n");
		}
	}
	//* task 2
	void Task2_Entry(void){
		while(1){
			print_str("task2-0\n");
			pxSuspendedTCB = pxCurrentTCB;
			vTaskSuspend(NULL);				//* test for vTaskSuspend

			print_str("task2-1\n");			
			vTaskDelay( 2 );				//*	test for vTaskDelay

			print_str("task2-2\n");
			vTaskDelay( 2 );			

			print_str("task2-3\n");
		}
	}
#endif	//*	End of test 1;
/*------------------------------------------------------------------------*/


/*------------------------------------------------------------------------*/
//*	test 2: multiple tasks with queue, semphr, countsem and MuxSem
#ifdef TEST_2
	#ifdef TEST_QUEUE
		//* variable for queue test
		#define QUEUE_LENGTH 10
		#define ITEM_SIZE sizeof( uint32_t )
		static StaticQueue_t xStaticQueue;
		QueueHandle_t xQueue;
		uint8_t ucQueueStorageArea[ QUEUE_LENGTH * ITEM_SIZE ];
	#endif
	#ifdef TEST_SEMPHR
		//* variable for semphr test
		SemaphoreHandle_t BinarySem_Handle =NULL;
		StaticQueue_t xStaticSemaphore;
	#endif
	#ifdef TEST_COUNTSEM
		//* for countsem test
		SemaphoreHandle_t CountSem_Handle =NULL;
		StaticQueue_t xStaticSemaphore;
	#endif
	#ifdef TEST_MUXSEM
		//* for MuxSem test
		SemaphoreHandle_t MuxSem_Handle;
		StaticQueue_t xMutexBuffer;
	#endif

	/*	main funciton*/
	void mainFreeRTOS(void){
		//* creat task
		Task1_Handle =
			xTaskCreateStatic( 
			(TaskFunction_t)Task1_Entry,	//* task entry (function name)
			(const char *)"Task1",			//* task name
			(uint32_t)TASK1_STACK_SIZE,		//* stack size of task, in word
			(void *) NULL,					//* function parameter
			3,								//* uxPriority
			(StackType_t *)Task1Stack,		//* stack addr of task
			(StaticTask_t *)&Task1TCB );	//* task block

		Task2_Handle =
			xTaskCreateStatic( 
			(TaskFunction_t)Task2_Entry,	//* task entry (function name)
			(const char *)"Task2",			//* task name
			(uint32_t)TASK2_STACK_SIZE,		//* stack size of task, in word
			(void *) NULL,					//* function parameter
			2,								//* uxPriority
			(StackType_t *)Task2Stack,		//* stack addr of task
			(StaticTask_t *)&Task2TCB );	//* task block

		//* create a task
		#ifdef TEST_QUEUE
			xQueue = xQueueCreateStatic( QUEUE_LENGTH,	//* depth
				ITEM_SIZE,					//* size of item
				ucQueueStorageArea,			//* queue buffer
				&xStaticQueue );			//* queue struct
		#endif
		#ifdef TEST_SEMPHR
			//* create a semphr
			BinarySem_Handle = xSemaphoreCreateBinaryStatic( &xStaticSemaphore );
		#endif
		#ifdef TEST_COUNTSEM
			//* create a count_semphr
			CountSem_Handle = xSemaphoreCreateCountingStatic(5,5,&xStaticSemaphore);
		#endif
		#ifdef TEST_MUXSEM
			//* create a MuxSem
			MuxSem_Handle = xSemaphoreCreateMutexStatic( &xMutexBuffer );
		#endif
		
		vPortConfigureSIE();				//*	preparation for SIE
		vTaskStartScheduler();				//*	start scheduling
	}

	//* task 1
	void Task1_Entry( void ){
		while(1){
			#ifdef TEST_QUEUE
				//* test for queue (as a receiver)
				BaseType_t xReturn = pdTRUE;
				uint32_t r_queue; 				//* save received content
				while (1) {
					xReturn = xQueueReceive( 
						xQueue,					//* handle
						&r_queue,				//* received content
						3);						//* timeTowait

					if (pdTRUE == xReturn){				
						print_str("<<-received content is ");
						print_dec(r_queue);
						print_str("\n");
					}
					else{
						print_str("<<-recv nothing!\n");
					}
					vTaskDelay(3);
				}
			#endif
			#ifdef TEST_SEMPHR
				//* test for semphr
				BaseType_t xReturn = pdPASS;
				while (1) {
					xReturn = xSemaphoreTake(BinarySem_Handle, 0); 
					if (pdTRUE == xReturn)
						print_str("recv successfully!\n");
					else
						print_str("recv error!\n");
					vTaskDelay(3);
				}
			#endif
			#ifdef TEST_COUNTSEM
				//* test for count_semphr
				BaseType_t xReturn = pdPASS;
				while (1) {
					xReturn = xSemaphoreTake(CountSem_Handle, 0); 
					if (pdTRUE == xReturn)
						print_str("recv successfully!\n");
					else
						print_str("recv error!\n");
					vTaskDelay(3);
				}
			#endif
			#ifdef TEST_MUXSEM
				//* test for MUX_semphr
				BaseType_t xReturn = pdPASS;
				while (1) {
					xReturn = xSemaphoreTake(MuxSem_Handle,0); 
					if (pdTRUE == xReturn)
						print_str("occupy by 1!\n");
					else
						print_str("occupy error!\n");
					vTaskDelay(10);
					xReturn = xSemaphoreGive( MuxSem_Handle );
				}
			#endif
		}
	}
	//* task 2
	void Task2_Entry(void){
		while(1){
			#ifdef TEST_QUEUE
				//*	test for queue (as a sender)
				BaseType_t xReturn = pdPASS;
				uint32_t send_data = 1;			//* save sending content
				while (1) {
					send_data = 1;
					print_str("->>send_data!\n");
					xReturn = xQueueSend( 
						xQueue, 				//* handle
						&send_data,				//* send data
						0 );					//* timeTowait

					if (pdPASS == xReturn)
						print_str("->>send successfully!\n\n");
					vTaskDelay(3);
				}
			#endif
			#ifdef TEST_SEMPHR
				//*	test for semphr
				BaseType_t xReturn = pdPASS;
				while (1) {
					xReturn = xSemaphoreGive( BinarySem_Handle );
					if ( xReturn == pdTRUE )
						print_str("release successfully!\n");
					else
						print_str("release error!\n");
					vTaskDelay(10);
				}
			#endif
			#ifdef TEST_COUNTSEM
				//*	test for count_semphr
				BaseType_t xReturn = pdPASS;
				while (1) {
					xReturn = xSemaphoreGive( CountSem_Handle );
					if ( xReturn == pdTRUE )
						print_str("release successfully!\n");
					else
						print_str("release error!\n");
					vTaskDelay(10);
				}
			#endif
			#ifdef TEST_MUXSEM
				//*	test for MUX_semphr
				BaseType_t xReturn = pdPASS;
				while (1) {
					xReturn = xSemaphoreGive( MuxSem_Handle );	//	BinarySem_Handle
					if ( xReturn == pdTRUE )
						print_str("release successfully!\n");
					else
						print_str("release error!\n");
					vTaskDelay(5);
					xReturn = xSemaphoreTake(MuxSem_Handle,0);
					if ( xReturn == pdTRUE )
						print_str("occupy by 2!\n");
				}
			#endif
		}
	}
#endif
//*	End of test 2;
/*------------------------------------------------------------------------*/
