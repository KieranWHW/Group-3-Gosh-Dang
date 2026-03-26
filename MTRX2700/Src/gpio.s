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
@ PA1 is used as the exit pin with active-low logic (pull-up enabled in initialise_io).
@ Briefly connect PA1 to GND to exit the loop. The function waits for PA1 to
@ float HIGH again before returning, so holding PA1 LOW keeps it in the exit
@ wait rather than returning immediately.
@ PA1 reads HIGH when floating (pull-up), LOW only when driven to GND.
@   + Input:  R8 = address of the task function to call
@             R11 = mode flag: TASK_MODE_ONCE (0) or TASK_MODE_HOLD (1)
@   + Output: None, returns after PA1 is pulled LOW then released
@   + Modifies: R9, R10 (used internally, not preserved)
gpio_do_task_pa0:
	PUSH {LR}

gpio_pa0_check_exit:
	@ Check if PA1 (exit pin) is LOW — active-low exit signal
	LDR R9, =GPIOA
	LDR R10, [R9, #IDR]             @ Read GPIOA input register
	ANDS R10, R10, #(1 << 1)        @ isolate PA1; Z flag set if LOW
	BEQ gpio_pa0_exit               @ Z set = PA1 LOW = exit requested

	@ Check if PA0 (user button) is pressed
	LDR R10, [R9, #IDR]             @ Read GPIOA input register again
	ANDS R10, R10, #1               @ Isolate PA0
	CMP R10, #1
	BNE gpio_pa0_check_exit         @ Not pressed -> Keep polling

	@ Button pressed -> execute the assigned task
	BLX R8

	CMP R11, #TASK_MODE_ONCE        @ Are we in once-per-tap mode?
	BEQ gpio_pa0_wait_release       @ Yes -> Wait for button release before next execution
	B gpio_pa0_debounce             @ TASK_MODE_HOLD -> Apply debounce delay then continue

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
	LDR R10, [R9, #IDR]             @ Read GPIOA input register
	ANDS R10, R10, #1               @ Isolate PA0
	CMP R10, #1
	BEQ gpio_pa0_wait_release       @ Still held -> Keep waiting for release
	B gpio_pa0_check_exit           @ Released -> Go back to polling

gpio_pa0_exit:
	@ PA1 went LOW — wait for it to go HIGH again before returning.
	@ This ensures a held-low PA1 does not cause an immediate return;
	@ the caller only resumes once PA1 is released back to its pull-up HIGH.
	LDR R9, =GPIOA
gpio_pa1_wait_release:
	LDR R10, [R9, #IDR]
	ANDS R10, R10, #(1 << 1)        @ isolate PA1; Z set if still LOW
	BEQ gpio_pa1_wait_release        @ Z set = still held to GND, keep waiting

	POP {PC}                         @ Z clear = PA1 HIGH (released) -> return to caller


@ ========== Helper ==========

@ Common return point for gpio functions
@   + Input: None
@   + Output: None, returns to caller
gpio_done:
	BX LR
