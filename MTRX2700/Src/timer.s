.syntax unified
.thumb
#include "definitions.s"


.data
@ define variables

.text
@ define code
@ All functions in this module are prefixed with "timer_" for clarity
@ when used alongside functions from other modules (e.g. uart_, gpio_, str_)


@ ========== Timer Control ==========

@ Start the timer by setting the CEN bit in CR1
@   + Input: None
@   + Output: None, timer begins counting
timer_start:
	LDR R0, =TIM2
	LDR R1, [R0, #TIM_CR1]
	ORR R1, R1, #(1 << TIM_CEN)
	STR R1, [R0, #TIM_CR1]

	BX LR


@ Stop the timer by clearing the CEN bit in CR1
@   + Input: None
@   + Output: None, timer stops counting
timer_stop:
	LDR R0, =TIM2
	LDR R1, [R0, #TIM_CR1]
	BIC R1, R1, #(1 << TIM_CEN)
	STR R1, [R0, #TIM_CR1]

	BX LR


@ ========== Output Compare ==========

@ Enable output compare for channel 1 on Timer 2
@   + Input: None
@   + Output: None, CC1E bit is set in CCER
timer_enable_compare:
	LDR R0, =TIM2
	LDR R1, [R0, #TIM_CCER]
	ORR R1, R1, #(1 << TIM_CC1E) @ Enable output compare for channel 1
	STR R1, [R0, #TIM_CCER]

	BX LR


@ ========== Delay ==========

@ Delay for a specific amount of time in microseconds using output compare on channel 1
@ Note: Requires PSC to be set to US_PSC_TIM2 (7) so each tick = 1 microsecond
@   + Input: R1 = delay time in microseconds
@   + Output: None, blocks until the delay has elapsed
@   + Modifies: R0, R1, R2, R3
timer_delay:
    PUSH {R1-R3, LR}
	LDR R0, =TIM2

	@ Set the compare value for channel 1
	STR R1, [R0, #TIM_CCR1]

	@ Reset the counter to 0 so we start counting from zero
	MOV R1, #0
	STR R1, [R0, #TIM_CNT]

	@ Clear any stale CC1F flag from a previous delay
	LDR R1, [R0, #TIM_SR]
	BIC R1, R1, #(1 << TIM_CC1F)
	STR R1, [R0, #TIM_SR]


timer_delay_loop:
	@ Poll the CC1F flag in SR until the counter matches CCR1
	LDR R3, [R0, #TIM_SR]
	ANDS R3, R3, #(1 << TIM_CC1F)
	BEQ timer_delay_loop @ Flag not set -> Keep waiting

	@ Delay complete, clear the CC1F flag so it is ready for next use
	LDR R2, [R0, #TIM_CNT] @ Store the value of the current completed period used for task 5.4.2b demo
	LDR R1, [R0, #TIM_SR]
	BIC R1, R1, #(1 << TIM_CC1F)
	STR R1, [R0, #TIM_SR]

	POP {R1-R3, PC}


@ Set the prescaler value for Timer 2
@ Note: Triggers an update event via EGR so the new PSC takes effect immediately
@ (PSC is a shadow register — it only updates on an update event)
@   + Input: R1 = prescaler value (PSC register value, actual divisor = PSC + 1)
@   + Output: None
@   + Modifies: R0, R1
timer_set_psc:
    LDR R0, =TIM2
    STR R1, [R0, #TIM_PSC]

    @ Force update event so PSC shadow register loads immediately
    MOV R1, #(1 << TIM_UG)
    STR R1, [R0, #TIM_EGR]

    BX LR


@ ========== ARR Preload Delay ==========

@ Delay using ARR preload — timer reloads entirely in hardware
@ ARPE=1 means ARR is buffered and reloads CNT automatically on overflow
@   + Input:  R1 = delay period in ticks (depends on current PSC)
@   + Output: None, blocks until one ARR period elapses
@   + Modifies: R0, R1
timer_delay_arr:
    PUSH {R1, LR}
    LDR R0, =TIM2

    @ Write the period into ARR
    STR R1, [R0, #TIM_ARR]

    @ Set ARPE=1 in CR1 so ARR is preloaded (buffered)
    LDR R1, [R0, #TIM_CR1]
    ORR R1, R1, #(1 << TIM_ARPE)
    STR R1, [R0, #TIM_CR1]

    @ Force update event so ARR shadow register loads immediately
    MOV R1, #(1 << TIM_UG)
    STR R1, [R0, #TIM_EGR]

    @ Clear UIF flag that the update event just set
    LDR R1, [R0, #TIM_SR]
    BIC R1, R1, #(1 << TIM_UIF)
    STR R1, [R0, #TIM_SR]

    @ Reset counter and wait for hardware to signal one full period
timer_arr_loop:
    LDR R1, [R0, #TIM_SR]
    ANDS R1, R1, #(1 << TIM_UIF)
    BEQ timer_arr_loop          @ UIF not set → hardware hasn't overflowed yet

    @ Clear UIF ready for next use
    LDR R1, [R0, #TIM_SR]
    BIC R1, R1, #(1 << TIM_UIF)
    STR R1, [R0, #TIM_SR]

    POP {R1, PC}
