.syntax unified
.thumb
#include "definitions.s"


.data
@ This is where we define constants

.text
/*
This is where we define code

Any functions defined in this module should be pre-fixed with "led_" for better clarification
when using them at the same time with functions from other modules, e.g. uart_, gpio_, .etc
*/




.type led_set_pattern, %function
/* This function sets the LEDs to a specific pattern
      + Input:  R7 = LED pattern byte (bit mask)
      + Output: None, pattern is written directly to the ODR register
      + Modifies: None, R9 is saved and restored
*/
led_set_pattern:
    PUSH {R9}
    LDR R9, =GPIOE @ Load GPIOE base address
    STRB R7, [R9, #ODR + 1] @ Write pattern to upper byte of ODR (PE8-PE15)
    POP {R9}
    B led_done



.type led_count, %function
/* This function use R7 to keep track of the current value that should be displayed by PE8-15*/
led_count:
	PUSH {LR}
	ADD R7, R7, #1 @ Increase the value of R7 when called
	BL led_set_pattern
	POP {PC}


/* This is a helper-function to return to the main function
      + Input: None
      + Output: None, return to main
*/
led_done:
    BX LR
