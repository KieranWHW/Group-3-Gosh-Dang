.syntax unified
.thumb

#include "definitions.s"

@ =============================================
@ Exercise 4 — Hardware Timers (5.4.2)
@ =============================================
@ Demonstrates output compare delay, prescaler selection and justification,
@ ARR preload (ARPE=1) delay, and two-LED independent blink at different frequencies.
@ Uses the timer_ and led_ helper modules.

@ Delay constants for 5.4.2a and 5.4.2c
.equ DELAY_5MLOOP,  0x4C4B40   @ 5,000,000 ticks = 5s  when PSC=7   (1 us/tick)
.equ DELAY_10KLOOP, 0x2710     @ 10,000 ticks    = 1s  when PSC=799 (0.1 ms/tick)


.text


@ ========== Demo Entry Point ==========

@ Run all Exercise 4 sub-tasks in sequence
@ 5.4.2a: Output compare delay — LEDs on for 5 seconds then off
@ 5.4.2b: Prescaler demo — count 10,000 x 0.1ms periods to confirm 1 second elapses
@ 5.4.2c: ARR preload (ARPE=1) delay — hardware-managed 1 second, then LEDs off
@ 5.4.2d: Two LEDs blinking at different frequencies driven from a 1ms tick
@   + Input: None
@   + Output: None
@   + Modifies: R0, R1, R4-R6 (R4-R6 saved/restored)
@ Register map:
@   R0  = scratch for PSC / ARR values and GPIOE base address
@   R1  = delay in ticks for timer_delay (5.4.2a spec uses R1)
@   R4  = LED1 tick counter (counts up to LED1_HALF_PERIOD)
@   R5  = LED2 tick counter (counts up to LED2_HALF_PERIOD)
@   R6  = scratch for ODR read-modify-write
.type ex4_run_demo, %function
ex4_run_demo:
    PUSH {R4-R6, LR}

    @ ===== Task 5.4.2a — output compare delay =====
    @ PSC=7 gives 1 us/tick (from enable_timer default)
    @ Turn on an LED pattern, wait 5 seconds using CC1 compare match, then clear
    MOV R7, #0b11001100
    BL led_set_pattern
    BL timer_enable_compare     @ enable CC1 output compare channel
    BL timer_start              @ start the counter (CEN=1)
    LDR R1, =DELAY_5MLOOP      @ R1 = 5,000,000 us = 5 seconds
    BL timer_delay
    MOV R7, #0x0
    BL led_set_pattern

    @ ===== Task 5.4.2b — prescaler selection and 0.1ms period demo =====
    @ PSC=799: 8MHz / (799+1) = 10kHz -> each tick = 0.1ms
    @ Count 10,000 periods of 0.1ms and verify that 1 second has elapsed
    @ Justification:
    @   1 us  resolution -> PSC = 7     (8MHz / 8 = 1MHz)
    @   1 ms  resolution -> PSC = 7999  (8MHz / 8000 = 1kHz)
    @   0.1ms resolution -> PSC = 799   (8MHz / 800 = 10kHz)
    @   For 1s max period at 1 us/tick: ARR can reach 1,000,000 (fits in 32-bit TIM2)
    @   For 1h at 1 us/tick: 3,600,000,000 ticks — exceeds 32-bit range (4,294,967,295 at limit)
    @   At PSC=7199 (0.9 us/tick): 3,600,000,000 / 1.25 = fits — but non-integer; use PSC=35999 for 4.5us
    @   Practical choice for 1h: PSC=35999 (4.5 us/tick), ARR=800,000,000 — still fits in TIM2 32-bit
    MOV R0, #799
    BL timer_set_psc            @ set PSC=799, triggers update event to load shadow register

    MOV R4, #0                  @ R4 = period counter
    LDR R5, =10000              @ target: 10,000 periods x 0.1ms = 1 second

ex4_psc_demo_loop:
    MOV R1, #1                  @ 1 tick = 0.1ms at PSC=799
    BL timer_delay              @ wait one 0.1ms period
    ADDS R4, R4, #1
    CMP R4, R5
    BLT ex4_psc_demo_loop       @ keep counting until 10,000 periods are done

    @ 1 second has elapsed — toggle LEDs to confirm
    MOV R7, #0b11001100
    BL led_set_pattern

    @ ===== Task 5.4.2c — ARR preload (ARPE=1) accurate delay =====
    @ ARPE=1 means ARR is double-buffered: the new value only loads on overflow
    @ so the period is entirely hardware-managed with no software jitter
    @ Using PSC=799 (still set from 5.4.2b), DELAY_10KLOOP = 10,000 ticks = 1 second
    LDR R0, =DELAY_10KLOOP     @ R0 = 10,000 ticks at PSC=799 = 1 second
    BL timer_delay_arr
    MOV R7, #0x0
    BL led_set_pattern

    @ ===== Task 5.4.2d — two LEDs at independent frequencies =====
    @ PSC=7999: 8MHz / (7999+1) = 1kHz -> each tick = 1ms
    @ LED1 (PE8): toggles every LED1_HALF_PERIOD ms  (default 500ms -> 1Hz blink)
    @ LED2 (PE9): toggles every LED2_HALF_PERIOD ms  (default 100ms -> 5Hz blink)
    @ Both counters are driven from the same 1ms tick but are fully independent
    @ Change LED1_HALF_PERIOD and LED2_HALF_PERIOD in definitions.s to adjust frequencies
    MOV R0, #7999
    BL timer_set_psc            @ PSC=7999 -> 1ms per tick

    MOV R4, #0                  @ R4 = LED1 tick accumulator
    MOV R5, #0                  @ R5 = LED2 tick accumulator

ex4_blink_loop:
    MOV R0, #1                  @ wait 1 tick = 1ms
    BL timer_delay_arr

    @ --- LED1 (PE8) ---
    ADDS R4, R4, #1
    MOV R0, #LED1_HALF_PERIOD
    CMP R4, R0
    BLT ex4_skip_led1
    MOV R4, #0                  @ reset LED1 counter
    LDR R0, =GPIOE
    LDR R6, [R0, #ODR]
    EOR R6, R6, #(1 << 8)      @ toggle PE8
    STR R6, [R0, #ODR]

ex4_skip_led1:
    @ --- LED2 (PE9) ---
    ADDS R5, R5, #1
    MOV R0, #LED2_HALF_PERIOD
    CMP R5, R0
    BLT ex4_skip_led2
    MOV R5, #0                  @ reset LED2 counter
    LDR R0, =GPIOE
    LDR R6, [R0, #ODR]
    EOR R6, R6, #(1 << 9)      @ toggle PE9
    STR R6, [R0, #ODR]

ex4_skip_led2:
    B ex4_blink_loop            @ loop forever, both LEDs driven independently
