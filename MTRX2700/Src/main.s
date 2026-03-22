.syntax unified
.thumb

#include "string.s"
#include "uart.s"
#include "gpio.s"
#include "definitions.s"
#include "initialise.s"
#include "led.s"


.global main

.type main, %function

@ Task 5.1.2 Constants
.equ LOWER_MODE, 0x00 @ Turning all letters to lower case
.equ UPPER_MODE, 0x01 @ Turning all letters to upper case

.data
@ define variables
string1: .asciz "GROUP 3"
buffer: .space 128 @ Free space in the memory for temporary used


.text
@ define text


main:
    BL enable_gpio_clocks
    BL initialise_io
    BL enable_uart

    LDR R1, =string1

    @ Task 5.1.2a
    BL str_reset_counter
    BL str_count

    @ Task 5.1.2b
    MOV R2, #LOWER_MODE     @ Choose a mode for the task here
    MOV R3, #0x0            @ Let R3 be the counter value, set to 0 initially

    CMP R2, #LOWER_MODE
    BEQ call_lower         @ If lower case mode, branch here
    CMP R2, #UPPER_MODE
    BEQ call_upper         @ If upper case mode, branch here

call_lower:
    BL str_lower_case
    B  continue_from_512b

call_upper:
    BL str_upper_case

continue_from_512b:
    @ Task 5.1.2c
    LDR R0, =string1 @ Let R0 point to the string
    LDR R1, =buffer  @ Let R1 point to the new address

    BL str_reset_counter @ Reset R2 to 0 before str_concat
    BL str_concat

    @ Task 5.1.2d
    BL str_checksum

    @ Task 5.1.2e
    BL str_verify_checksum @ Set R3 to 0 if the checksum is correct

	@ Task 5.2.2a
	MOV R7, #LED_PATTERN @ Set the LED pattern to display in R7
	BL led_set_pattern @ Point R8 to the LED task

	@ Task 5.2.2b, c, d
	MOV R7, #0x0 @ Reset R7 to 0 so it can be used as the counter of led_count
	@BL led_set_pattern @ Clear current LED
	@LDR R8, =led_count  @ Point R8 to the LED task
	@MOV R11, #TASK_MODE_ONCE @ Keep executing while button is held
	@BL gpio_do_task_pa0  @ Hand control to button handler, exits when PA1 goes HIGH

	LDR R8, =task_uart_transmit  @ Point R8 to the transmit wrapper
	MOV R11, #TASK_MODE_HOLD @ Transmit once per tap
	BL gpio_do_task_pa0

	B end


end:
    @ End here, inf loop
    B end


@ Task wrapper so gpio_do_task_pa0 can call uart_transmit via R
.type task_uart_transmit, %function
task_uart_transmit:
    PUSH {LR}
    LDR R1, =buffer @ Point R1 to the packet buffer
    BL uart_transmit @ Transmit the packet
    POP {PC}

