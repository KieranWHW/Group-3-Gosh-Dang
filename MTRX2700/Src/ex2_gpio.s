.syntax unified
.thumb

#include "definitions.s"

@ =============================================
@ Exercise 2 — Digital I/O (5.2.2)
@ =============================================
@ Demonstrates LED pattern output, button-driven binary counter,
@ up/down direction reversal, debounce, and a timed auto-counter.
@ Uses the gpio_, led_ and timer_ helper modules.
@
@ Mode selection (change EX2_AUTO_MODE and rebuild to switch):
@   EX2_AUTO_MODE = 0  ->  button-driven counter  (5.2.2b-d)
@   EX2_AUTO_MODE = 1  ->  timed auto-counter      (5.2.2e)
@ Each mode loops forever; reset the board to restart.

@ Set to 1 to run timed auto-counter (5.2.2e),
@ set to 0 to run button-press counter (5.2.2b-d)
.equ EX2_AUTO_MODE, 1

@ Auto-counter step period in microseconds (5.2.2e)
@ 500,000 us = 500ms per step at PSC=7 (1 us/tick)
.equ EX2_AUTO_DELAY_US, 500000


.data
led_dir: .byte 0    @ direction flag: 0 = counting up, 1 = counting down


.text


@ ========== Demo Entry Point ==========

@ Run Exercise 2 sub-tasks
@ 5.2.2a: Show a fixed LED pattern briefly, then enter the selected mode
@ 5.2.2b-d: Button-driven binary counter — press PA0 to step, loops forever
@ 5.2.2e:   Timed auto-counter — steps every EX2_AUTO_DELAY_US, loops forever
@ Change EX2_AUTO_MODE above and rebuild to switch between the two modes.
@   + Input: None
@   + Output: None (does not return)
@   + Modifies: R0, R4, R5, R7, R8, R11
@ Register map:
@   R4  = scratch for mode check and direction reads
@   R5  = scratch for direction writes and timer delay
@   R7  = LED counter value (persists across ex2_led_step calls)
@   R8  = task function pointer passed to gpio_do_task_pa0
@   R11 = task mode flag passed to gpio_do_task_pa0
.type ex2_run_demo, %function
ex2_run_demo:
    PUSH {R4, R5, LR}

    @ ===== Task 5.2.2a — set a fixed LED pattern =====
    MOV R7, #LED_PATTERN        @ default debug pattern from definitions.s
    BL led_set_pattern

    @ Branch to the selected mode based on the compile-time constant
    MOV R4, #EX2_AUTO_MODE
    CMP R4, #1
    BEQ ex2_timed_start

    @ ===== Tasks 5.2.2b, c, d — button counter with debounce =====
    @ Each press of PA0 calls ex2_led_step, which increments or decrements
    @ R7 and flips direction automatically at 0x00 and 0xFF.
    @ gpio_do_task_pa0 with TASK_MODE_ONCE handles the press-release debounce.
    @ This loop runs forever; reset the board to exit.
    MOV R7, #0x0
    BL led_set_pattern
    LDR R8, =ex2_led_step       @ task to run on each button press
    MOV R11, #TASK_MODE_ONCE    @ one step per tap, wait for button release
    BL gpio_do_task_pa0         @ never returns

ex2_timed_start:
    @ ===== Task 5.2.2e — timed auto-counter =====
    @ Steps R7 automatically every EX2_AUTO_DELAY_US microseconds.
    @ This loop runs forever; reset the board to exit.
    MOV R7, #0x0
    BL led_set_pattern
    LDR R4, =led_dir            @ reset direction to counting up
    MOV R5, #0
    STRB R5, [R4]
    BL timer_start

ex2_timed_loop:
    LDR R0, =EX2_AUTO_DELAY_US  @ delay between steps (1 us/tick at PSC=7)
    BL timer_delay_arr
    BL ex2_led_step
    B ex2_timed_loop            @ loop forever


@ ========== LED Step Helper ==========

@ Step the LED counter one position and update the display.
@ Direction reverses automatically at the boundary values:
@   0xFF (all LEDs on)  -> switch to counting down
@   0x00 (all LEDs off) -> switch to counting up
@ Direction state is stored in the led_dir memory variable.
@   + Input:  R7 = current counter value
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
    CMP R7, #0x00               @ all LEDs off — switch direction to up
    BNE ex2_step_done
    MOV R5, #0
    STRB R5, [R4]
    B ex2_step_done

ex2_step_up:
    ADDS R7, R7, #1
    BL led_set_pattern
    CMP R7, #0xFF               @ all LEDs on — switch direction to down
    BNE ex2_step_done
    MOV R5, #1
    STRB R5, [R4]

ex2_step_done:
    POP {R4, R5, PC}
