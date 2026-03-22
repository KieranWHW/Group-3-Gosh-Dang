.syntax unified
.thumb
#include "definitions.s"

.data
@ This is where we define constants

.text
/*
This is where we define code

Any functions defined in this module should be pre-fixed with "gpio_" for better clarification
when using them at the same time with functions from other modules, e.g. uart_, timer_, .etc

Avoid using R8 and R11 anywhere else as these registers are used as task pointer and mode flag
for gpio_do_task_pa0
*/


/* This function executes a task assigned in R8 triggered by PA0 button
      + Input:  R8 = address of the task label to call
                R11 = mode flag: TASK_MODE_ONCE (0) = execute once per tap,
                                 TASK_MODE_HOLD (1) = keep executing while held
      + Output: None, returns when PA1 goes HIGH
      + Modifies: R9, R10 (used internally, not preserved)
      + Note: PA1 is the exit pin - HIGH exits the loop, LOW/not connected keeps looping
              PA1 has a pull-down enabled in initialise_io so floating reads as LOW
*/
gpio_do_task_pa0:
    PUSH {LR}

gpio_pa0_check_exit:
    LDR R9, =GPIOA
    LDR R10, [R9, #IDR] @ Read GPIOA input register
    ANDS R10, R10, #(1 << 1) @ Isolate PA1 (exit pin)
    CMP R10, #(1 << 1)
    BEQ gpio_pa0_exit @ PA1 HIGH -> Exit the loop and return to caller

    LDR R10, [R9, #IDR]  @ Read GPIOA input register again
    ANDS R10, R10, #1 @ Isolate PA0 (user button)
    CMP R10, #1
    BNE gpio_pa0_check_exit  @ Not pressed -> Keep polling

    @ Button pressed -> execute the assigned task
    BLX R8  @ Call the task pointed to by R8

    CMP R11, #TASK_MODE_ONCE @ Check if we are in once-per-tap mode
    BEQ gpio_pa0_wait_release @ Yes -> Wait for button release before next execution
    B delay_inner @ TASK_MODE_HOLD -> Keep executing while held

delay_inner:
	PUSH {R10}
	LDR R10, =0xFFFFF
delay_loop:
	SUBS R10, R10, #1
	BNE delay_loop
delay_exit:
	POP {R10}
	B gpio_pa0_check_exit

gpio_pa0_wait_release:
    LDR R9, =GPIOA
    LDR R10, [R9, #IDR] @ Read GPIOA input register
    ANDS R10, R10, #1  @ Isolate PA0
    CMP R10, #1
    BEQ gpio_pa0_wait_release  @ Still held -> Keep waiting for release
    B gpio_pa0_check_exit @ Released -> Go back to polling

gpio_pa0_exit:
    POP {PC}                        @ Return to caller


/* This is a helper-function to return to the main function
    + Input: None
    + Output: None, return to main
*/
gpio_done:
    BX LR
