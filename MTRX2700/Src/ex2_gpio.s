.syntax unified
.thumb

#include "definitions.s"

@ =============================================
@ Exercise 2 — Digital I/O (5.2.2)
@ =============================================
@ Demonstrates LED pattern output, button-driven binary counter,
@ up/down direction reversal, debounce, and a timed auto-counter.
@ Uses the gpio_, led_ and timer_ helper modules.

@ Set to 1 to run timed auto-counter (5.2.2e),
@ set to 0 to run button-press counter (5.2.2b-d)
.equ EX2_AUTO_MODE, 0

@ Auto-counter step period in microseconds (5.2.2e)
@ 500,000 us = 500ms per step with PSC=7 (1 us/tick, default from enable_timer)
.equ EX2_AUTO_DELAY_US, 500000


.data
led_dir: .byte 0    @ direction flag for the counter: 0 = counting up, 1 = counting down


.text


@ ========== Demo Entry Point ==========

@ Run Exercise 2 sub-tasks
@ 5.2.2a: Show a fixed LED pattern
@ 5.2.2b-d: Button-driven binary counter with direction reversal and debounce
@           Exit by pulling PA1 HIGH to advance to 5.2.2e
@ 5.2.2e: Timed auto-counter — steps at EX2_AUTO_DELAY_US intervals
@         Change EX2_AUTO_MODE to switch between button and timed mode
@   + Input: None
@   + Output: None
@   + Modifies: R4, R5, R7, R8, R11 (R4, R5 saved/restored)
@ Register map:
@   R4  = scratch for mode/direction reads
@   R5  = scratch for PA1 exit check in timed loop
@   R7  = LED counter (persistent across ex2_led_step calls)
@   R8  = task function pointer passed to gpio_do_task_pa0
@   R11 = task mode flag passed to gpio_do_task_pa0
.type ex2_run_demo, %function
ex2_run_demo:
    PUSH {R4, R5, LR}

    @ ===== Task 5.2.2a — set a fixed LED pattern =====
    MOV R7, #LED_PATTERN        @ load the default debug pattern from definitions
    BL led_set_pattern

    @ Select which demo to run based on EX2_AUTO_MODE
    MOV R4, #EX2_AUTO_MODE
    CMP R4, #1
    BEQ ex2_timed_start

    @ ===== Tasks 5.2.2b, c, d — button counter with debounce =====
    @ ex2_led_step increments/decrements R7 and flips direction at the limits
    @ Debounce is handled inside gpio_do_task_pa0 (TASK_MODE_ONCE waits for release)
    @ Pull PA1 HIGH to exit this loop and return to caller
    MOV R7, #0x0                @ clear LEDs before starting the counter
    BL led_set_pattern
    LDR R8, =ex2_led_step       @ R8 = task to run on each button press
    MOV R11, #TASK_MODE_ONCE    @ one step per tap, wait for button release
    BL gpio_do_task_pa0         @ blocks until PA1 goes HIGH

    POP {R4, R5, PC}            @ done with button demo — return to main

ex2_timed_start:
    @ ===== Task 5.2.2e — timed auto-counter =====
    @ Resets the counter and direction, starts the timer, then steps
    @ automatically at EX2_AUTO_DELAY_US intervals
    @ Pull PA1 HIGH at any time to exit
    MOV R7, #0x0                @ reset counter to zero
    BL led_set_pattern
    LDR R4, =led_dir            @ reset direction to counting up
    MOV R5, #0
    STRB R5, [R4]
    BL timer_start              @ ensure the timer is running

ex2_timed_loop:
    @ Check if PA1 is HIGH — exit the loop if so
    LDR R4, =GPIOA
    LDR R5, [R4, #IDR]
    ANDS R5, R5, #(1 << 1)     @ isolate PA1
    CMP R5, #(1 << 1)
    BEQ ex2_timed_done          @ PA1 HIGH -> exit

    @ Wait one step period then advance the counter
    LDR R0, =EX2_AUTO_DELAY_US @ R0 = delay in ticks (1 us/tick at PSC=7)
    BL timer_delay_arr
    BL ex2_led_step
    B ex2_timed_loop

ex2_timed_done:
    POP {R4, R5, PC}


@ ========== LED Step Helper ==========

@ Step the LED counter one position and update the display
@ Direction reverses automatically at the boundary values:
@   0xFF (all LEDs on)  -> switch to counting down
@   0x00 (all LEDs off) -> switch to counting up
@ Direction state is stored in the led_dir memory variable
@   + Input:  R7 = current LED counter value
@   + Output: R7 = updated counter value, LEDs refreshed
@   + Modifies: R4, R5 (saved/restored)
.type ex2_led_step, %function
ex2_led_step:
    PUSH {R4, R5, LR}

    LDR R4, =led_dir
    LDRB R5, [R4]               @ R5 = current direction (0=up, 1=down)

    CMP R5, #0
    BEQ ex2_step_up

ex2_step_down:
    SUBS R7, R7, #1
    BL led_set_pattern
    CMP R7, #0x00               @ All LEDs off — switch direction back to up
    BNE ex2_step_done
    MOV R5, #0
    STRB R5, [R4]
    B ex2_step_done

ex2_step_up:
    ADDS R7, R7, #1
    BL led_set_pattern
    CMP R7, #0xFF               @ All LEDs on — switch direction to down
    BNE ex2_step_done
    MOV R5, #1
    STRB R5, [R4]

ex2_step_done:
    POP {R4, R5, PC}
