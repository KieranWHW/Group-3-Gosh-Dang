.syntax unified
.thumb
#include "definitions.s"

.data
@ define variables

.text
@ define code
@ All functions in this module are prefixed with "gpio_" for clarity
@ when used alongside functions from other modules (e.g. uart_, led_, str_)
@ Avoid using R8 and R11 elsewhere as they are reserved for task pointer and mode flag


@ ========== Button Task Handler ==========

@ Execute a task assigned in R8, triggered by the PA0 user button
@ Supports two modes: execute once per tap (TASK_MODE_ONCE) or continuously while held (TASK_MODE_HOLD)
@ PA1 is used as the exit pin - pulling PA1 HIGH exits the loop and returns to caller
@ PA1 has a pull-down enabled in initialise_io so it reads LOW when floating
@   + Input:  R8 = address of the task function to call
@             R11 = mode flag: TASK_MODE_ONCE (0) or TASK_MODE_HOLD (1)
@   + Output: None, returns when PA1 goes HIGH
@   + Modifies: R9, R10 (used internally, not preserved)
gpio_do_task_pa0:
	PUSH {LR}

gpio_pa0_check_exit:
	@ Check if PA1 (exit pin) is HIGH
	LDR R9, =GPIOA
	LDR R10, [R9, #IDR] @ Read GPIOA input register
	ANDS R10, R10, #(1 << 1) @ Isolate PA1
	CMP R10, #(1 << 1)
	BEQ gpio_pa0_exit @ PA1 HIGH -> Exit the loop and return to caller

	@ Check if PA0 (user button) is pressed
	LDR R10, [R9, #IDR] @ Read GPIOA input register again
	ANDS R10, R10, #1 @ Isolate PA0
	CMP R10, #1
	BNE gpio_pa0_check_exit @ Not pressed -> Keep polling

	@ Button pressed -> execute the assigned task
	BLX R8

	CMP R11, #TASK_MODE_ONCE @ Are we in once-per-tap mode ?
	BEQ gpio_pa0_wait_release @ Yes -> Wait for button release before next execution
	B gpio_pa0_debounce @ TASK_MODE_HOLD -> Apply debounce delay then continue

@ Simple software delay for debouncing in TASK_MODE_HOLD
gpio_pa0_debounce:
	PUSH {R10}
	LDR R10, =0xFFFFF
gpio_pa0_debounce_loop:
	SUBS R10, R10, #1
	BNE gpio_pa0_debounce_loop
	POP {R10}
	B gpio_pa0_check_exit

@ Wait for button release before allowing next execution in TASK_MODE_ONCE
gpio_pa0_wait_release:
	LDR R9, =GPIOA
	LDR R10, [R9, #IDR] @ Read GPIOA input register
	ANDS R10, R10, #1 @ Isolate PA0
	CMP R10, #1
	BEQ gpio_pa0_wait_release @ Still held -> Keep waiting for release
	B gpio_pa0_check_exit @ Released -> Go back to polling

gpio_pa0_exit:
	POP {PC} @ Return to caller


@ ========== Helper ==========

@ Common return point for gpio functions
@   + Input: None
@   + Output: None, returns to caller
gpio_done:
	BX LR



