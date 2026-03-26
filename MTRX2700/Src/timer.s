.syntax unified
.thumb
#include "definitions.s"


.data
@ define variables

.text
@ define code
@ All functions in this module are prefixed with "timer_" for clarity
@ when used alongside functions from other modules (e.g. uart_, gpio_, str_)
@ Register convention: only timer_delay uses R1 (per 5.4.2a spec).
@ All other functions use R0 for input and R4+ for scratch,
@ keeping R1-R3 free for the string/UART pipeline.


@ ========== Timer Control ==========

@ Start the timer by setting the CEN bit in CR1
@   + Input: None
@   + Output: None, timer begins counting
@   + Modifies: R0
timer_start:
	PUSH {R4}
	LDR R4, =TIM2
	LDR R0, [R4, #TIM_CR1]
	ORR R0, R0, #(1 << TIM_CEN)
	STR R0, [R4, #TIM_CR1]
	POP {R4}

	BX LR


@ Stop the timer by clearing the CEN bit in CR1
@   + Input: None
@   + Output: None, timer stops counting
@   + Modifies: R0
timer_stop:
	PUSH {R4}
	LDR R4, =TIM2
	LDR R0, [R4, #TIM_CR1]
	BIC R0, R0, #(1 << TIM_CEN)
	STR R0, [R4, #TIM_CR1]
	POP {R4}

	BX LR


@ ========== Output Compare ==========

@ Enable output compare for channel 1 on Timer 2
@   + Input: None
@   + Output: None, CC1E bit is set in CCER
@   + Modifies: R0
timer_enable_compare:
	PUSH {R4}
	LDR R4, =TIM2
	LDR R0, [R4, #TIM_CCER]
	ORR R0, R0, #(1 << TIM_CC1E) @ enable channel 1
	STR R0, [R4, #TIM_CCER]
	POP {R4}

	BX LR


@ ========== Delay (Output Compare) ==========

@ Delay for a specific number of microseconds using output compare on channel 1
@ Requires PSC to be set so each tick = 1 microsecond (US_PSC_TIM2 = 7)
@   + Input: R1 = delay time in microseconds (kept per 5.4.2a spec)
@   + Output: None, blocks until the delay has elapsed
@   + Modifies: R0
timer_delay:
	PUSH {R4-R5, LR}
	LDR R4, =TIM2

	@ Set the compare value for channel 1
	STR R1, [R4, #TIM_CCR1]

	@ Reset the counter to 0 so we start counting from zero
	MOV R5, #0
	STR R5, [R4, #TIM_CNT]

	@ Clear any stale CC1F flag from a previous delay
	LDR R5, [R4, #TIM_SR]
	BIC R5, R5, #(1 << TIM_CC1F)
	STR R5, [R4, #TIM_SR]

timer_delay_loop:
	@ Poll the CC1F flag in SR until the counter matches CCR1
	LDR R5, [R4, #TIM_SR]
	ANDS R5, R5, #(1 << TIM_CC1F)
	BEQ timer_delay_loop @ flag not set, keep waiting

	@ Delay complete, clear the CC1F flag so it is ready for next use
	LDR R5, [R4, #TIM_SR]
	BIC R5, R5, #(1 << TIM_CC1F)
	STR R5, [R4, #TIM_SR]

	POP {R4-R5, PC}


@ ========== Prescaler ==========

@ Set the prescaler value for Timer 2
@ Triggers an update event via EGR so the new PSC takes effect immediately
@ (PSC is a shadow register — it only updates on an update event)
@   + Input: R0 = prescaler value (actual divisor = PSC + 1)
@   + Output: None
@   + Modifies: R0
timer_set_psc:
	PUSH {R4}
	LDR R4, =TIM2
	STR R0, [R4, #TIM_PSC]

	@ Force update event so PSC shadow register loads immediately
	MOV R0, #(1 << TIM_UG)
	STR R0, [R4, #TIM_EGR]

	POP {R4}
	BX LR


@ ========== ARR Preload Delay ==========

@ Delay using ARR preload — timer reloads entirely in hardware
@ ARPE=1 means ARR is buffered and reloads CNT automatically on overflow
@   + Input: R0 = delay period in ticks (depends on current PSC)
@   + Output: None, blocks until one ARR period elapses
@   + Modifies: R0
timer_delay_arr:
	PUSH {R4-R5, LR}
	LDR R4, =TIM2

	@ Write the period into ARR
	STR R0, [R4, #TIM_ARR]

	@ Set ARPE=1 in CR1 so ARR is preloaded (buffered)
	LDR R5, [R4, #TIM_CR1]
	ORR R5, R5, #(1 << TIM_ARPE)
	STR R5, [R4, #TIM_CR1]

	@ Force update event so ARR shadow register loads immediately
	MOV R5, #(1 << TIM_UG)
	STR R5, [R4, #TIM_EGR]

	@ Clear UIF flag that the update event just set
	LDR R5, [R4, #TIM_SR]
	BIC R5, R5, #(1 << TIM_UIF)
	STR R5, [R4, #TIM_SR]

timer_arr_loop:
	@ Poll UIF until hardware signals overflow
	LDR R5, [R4, #TIM_SR]
	ANDS R5, R5, #(1 << TIM_UIF)
	BEQ timer_arr_loop @ UIF not set, hardware hasn't overflowed yet

	@ Clear UIF ready for next use
	LDR R5, [R4, #TIM_SR]
	BIC R5, R5, #(1 << TIM_UIF)
	STR R5, [R4, #TIM_SR]

	POP {R4-R5, PC}
