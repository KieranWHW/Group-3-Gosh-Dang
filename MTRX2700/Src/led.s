.syntax unified
.thumb
#include "definitions.s"


.data
@ define variables

.text
@ define code
@ All functions in this module are prefixed with "led_" for clarity
@ when used alongside functions from other modules (e.g. uart_, gpio_, str_)


@ ========== LED Control ==========

@ Set the LEDs (PE8-PE15) to a specific pattern using a bitmask
@ Each bit in R7 corresponds to one LED: bit 0 = PE8, bit 7 = PE15
@   + Input: R7 = LED pattern byte (bit mask)
@   + Output: None, pattern is written directly to the ODR upper byte
@   + Modifies: R9 (saved and restored)
.type led_set_pattern, %function
led_set_pattern:
	PUSH {R9}
	LDR R9, =GPIOE @ Load GPIOE base address
	STRB R7, [R9, #ODR + 1] @ Write pattern to upper byte of ODR (PE8-PE15)
	POP {R9}
	B led_done


@ Increment the LED counter and update the display
@ R7 acts as a persistent counter across calls, incrementing by 1 each time
@   + Input: R7 = current counter value
@   + Output: R7 = incremented counter value, LEDs updated to show new value
.type led_count, %function
led_count:
	PUSH {LR}
	ADD R7, R7, #1 @ Increase the counter value
	BL led_set_pattern @ Update LEDs to show the new count
	POP {PC}


@ ========== Helper ==========

@ Common return point for led functions
@   + Input: None
@   + Output: None, returns to caller
led_done:
	BX LR
