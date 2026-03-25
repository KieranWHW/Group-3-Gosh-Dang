.syntax unified
.thumb

#include "string.s"
#include "uart.s"
#include "gpio.s"
#include "definitions.s"
#include "initialise.s"
#include "timer.s"
#include "led.s"


.equ DELAY_5MLOOP, 0x4C4B40 @ = 5x10^(6) loop to trigger CCR1, delay the code stream for 5s if TIMER PSC = 7
.equ DELAY_10KLOOP, 0x2710 @ = 10x10^(3) loop to trigger CCR1, delay the code stream for 1s if TIMER PSC =799

.global main

.type main, %function

@ Task 5.1.2 Constants
.equ LOWER_MODE, 0x00 @ Turning all letters to lower case
.equ UPPER_MODE, 0x01 @ Turning all letters to upper case

.data
@ define variables
string1: .asciz "GROUP 3"
buffer: .space 128 @ Free space in memory for temporary use
buffer2: .space 128


.text
@ define code


main:
	BL enable_gpio_clocks
	BL initialise_io
	BL enable_uart
	BL enable_timer

	LDR R1, =string1

	@ Task 5.1.2a - Calculate string length
	BL str_reset_counter
	BL str_count

	@ Task 5.1.2b - Convert string to upper or lower case based on mode
	MOV R2, #LOWER_MODE @ Choose a mode for the task here
	MOV R3, #0x0 @ Let R3 be the counter value, set to 0 initially

	CMP R2, #LOWER_MODE
	BEQ call_lower @ If lower case mode, branch here
	CMP R2, #UPPER_MODE
	BEQ call_upper @ If upper case mode, branch here

call_lower:
	BL str_lower_case
	B  continue_from_512b

call_upper:
	BL str_upper_case

continue_from_512b:
	@ Task 5.1.2c - Format the string into a UART packet with STX, length, body and ETX
	LDR R0, =string1 @ Let R0 point to the source string
	LDR R1, =buffer @ Let R1 point to the destination buffer

	BL str_reset_counter @ Reset R2 to 0 before str_concat
	BL str_concat

	@ Task 5.1.2d - Compute and append BCC checksum to the packet
	BL str_checksum

	@ Task 5.1.2e - Verify the checksum, R3 = 0 if correct
	BL str_verify_checksum


	@ Task 5.2.2a - Set LEDs to a specific pattern
	MOV R7, #LED_PATTERN @ Set the LED pattern to display in R7
	BL led_set_pattern

	@ Task 5.2.2b, c, d - LED counter with button input
	MOV R7, #0x0 @ Reset R7 to 0 so it can be used as the counter for led_count
	BL led_set_pattern
	@BL led_set_pattern @ Clear current LED
	@LDR R8, =led_count @ Point R8 to the LED task
	@MOV R11, #TASK_MODE_ONCE @ Execute once per tap
	@BL gpio_do_task_pa0 @ Hand control to button handler, exits when PA1 goes HIGH

	@ Task 5.3.2 - UART transmit triggered by button / receive and validate
	@LDR R8, =task_uart_transmit @ Point R8 to the transmit wrapper
	@MOV R11, #TASK_MODE_HOLD @ Transmit once per tap
	@BL gpio_do_task_pa0

	LDR R2, =buffer2
	BL uart_read_check

	@ Task 5.4.2a
	@ Turn on the LEDs and turn them off after 5 seconds
	MOV R7, #0b11001100
	BL led_set_pattern
	BL timer_enable_compare
	BL timer_start
	LDR R1, =DELAY_5MLOOP
	BL timer_delay
	MOV R7, #0x0
	BL led_set_pattern

	@ Task 5.4.2b
	@ We have to set another PSC value to get the specified 0.1ms delay period
	@ We first find the required freq by 1/ (0.1*10^(-3)) = 10kHz
	@ plug in the formula we get PSC = (8MHz/10kHz) - 1 = 799
	MOV R1, #799
	BL timer_set_psc

	MOV R4, #0 @ R4 = period counter
	LDR R5, =10000 @ target: 10,000 periods

	demo_count_loop:
	    MOV R1, #1 @ 1 tick = 0.1ms at PSC=799
	    BL timer_delay
	    ADD R4, R4, #1
	    CMP R4, R5
	    BLT demo_count_loop

	@ R4 = 10000 here — 1 second has elapsed
	@ Toggle LED or send UART to signal completion
	MOV R7, #0b11001100
	BL led_set_pattern

	@ Task 5.4.2c
	LDR R1, =DELAY_10KLOOP
	@ Delay 1 secs
	BL timer_delay_arr
	MOV R7, #0x0
	BL led_set_pattern

	@ Task 5.4.2d
	@ Task 5.4.2d — two LEDs at different frequencies
	@ R4 = LED1 counter, R5 = LED2 counter
	@ R6 = LED1 state, R7 = LED2 state (0 or 1)
	MOV R1, #7999
	BL timer_set_psc @ Set timer to 1ms delay period
	@ R4 = LED1 counter, R5 = LED2 counter
	@ No state variables needed — ODR holds the truth

	MOV R4, #0
	MOV R5, #0

	blink_loop:
	    MOV R1, #1
	    BL timer_delay_arr          @ 1ms tick

	    @ --- LED1 (PE8) ---
	    ADD R4, R4, #1
	    MOV R0, #LED1_HALF_PERIOD
	    CMP R4, R0
	    BLT skip_led1
	    MOV R4, #0
	    LDR R0, =GPIOE
	    LDR R1, [R0, #ODR]
	    EOR R1, R1, #(1 << 8)      @ toggle PE8
	    STR R1, [R0, #ODR]

	skip_led1:
	    @ --- LED2 (PE9) ---
	    ADD R5, R5, #1
		MOV R0, #LED2_HALF_PERIOD
		CMP R5, R0
	    BLT skip_led2
	    MOV R5, #0
	    LDR R0, =GPIOE
	    LDR R1, [R0, #ODR]
	    EOR R1, R1, #(1 << 9)      @ toggle PE9
	    STR R1, [R0, #ODR]

	skip_led2:
	    B blink_loop


	B end


end:
	@ Infinite loop to prevent falling off into undefined memory
	B end


@ Task wrapper so gpio_do_task_pa0 can call uart_transmit via R8
.type task_uart_transmit, %function
task_uart_transmit:
	PUSH {LR}
	LDR R1, =buffer @ Point R1 to the packet buffer
	BL uart_transmit @ Transmit the packet
	POP {PC}
