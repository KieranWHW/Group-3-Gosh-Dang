.syntax unified
.thumb

#include "definitions.s"

.text
@ define code


@ ========== GPIO Clock Setup ==========

@ Enable the clocks for the GPIO peripherals we are using (Port A, C and E)
enable_gpio_clocks:
	LDR R0, =RCC @ load the address of the RCC address boundary (for enabling the IO clock)
	LDR R1, [R0, #AHBENR] @ load the current value of the peripheral clock registers
	ORR R1, R1, #((1 << PA_AHB_OFFSET) | (1 << PC_AHB_OFFSET) | (1 << PE_AHB_OFFSET)) @ Enabling the clock for Port A, C and E
	STR R1, [R0, #AHBENR] @ store the modified register back to the submodule
	BX LR @ return


@ ========== GPIO Pin Mode Setup ==========

@ Initialise the discovery board I/O pin modes
@ PE8-PE15 are set to output for LEDs, PC10-PC11 are set to alternate function for UART4
@ Input pins (e.g. PA0 for button) are input by default so no setup needed
initialise_io:
	@ Configure PE8-PE15 as general purpose output for driving LEDs
	LDR R0, =GPIOE
	LDR R1, [R0, #MODER]
	LDR R2, =0xFFFF0000 @ mask for PE8-15 mode fields (2 bits per pin)
	BIC R1, R1, R2 @ clear PE8-15 mode bits
	LDR R2, =0x55550000 @ output mode (01) for PE8-15
	ORR R1, R1, R2 @ set PE8-15 to output
	STR R1, [R0, #MODER]

	@ Configure PC10 and PC11 to Alternate Function mode (MODER = 0b10) for UART4
	LDR R0, =GPIOC
	LDR R1, [R0, #MODER]
	BIC R1, R1, #(0xF << 20) @ Clear bits [23:20] for PC10 and PC11
	ORR R1, R1, #(0xA << 20) @ Set 10_10 -> AF mode for both pins
	STR R1, [R0, #MODER]

	BX LR @ return from function call


@ ========== UART4 Setup ==========

@ Top-level function to fully initialise UART4 on PC10 (TX) and PC11 (RX)
@ Calls each sub-step in order: pin function, speed, clock, baud rate, then control register
enable_uart:
	PUSH {LR} @ Save LR so we can return to main after finishing UART setup
	BL set_afrh
	BL enable_high_speed
	BL enable_uart_clock
	BL set_baud_rate
	BL enable_uart_cr1
	POP {PC} @ Return to main


@ Assign Alternate Function 5 (UART4) to PC10 (TX) and PC11 (RX)
set_afrh:
	LDR R0, =GPIOC
	LDR R1, [R0, #AFRH]
	BIC R1, R1, #(0xFF << AFR10) @ Clear 4-bit AF fields for PC10 [11:8] and PC11 [15:12]
	ORR R1, R1, #(0x55 << AFR10) @ Set AF5 (0101) for both PC10 and PC11
	STR R1, [R0, #AFRH]
	BX LR


@ Set PC10 and PC11 to high speed (0b11) for reliable UART at higher baud rates
enable_high_speed:
	LDR R0, =GPIOC
	LDR R1, [R0, #OSPEEDR]
	BIC R1, R1, #(0xF << OSPEEDR10) @ Clear 2-bit speed fields for PC10 [21:20] and PC11 [23:22]
	ORR R1, R1, #(0xF << OSPEEDR10) @ Set high speed (11) for both pins
	STR R1, [R0, #OSPEEDR]
	BX LR


@ Enable the peripheral clock for UART4 on the APB1 bus
enable_uart_clock:
	LDR R0, =RCC
	LDR R1, [R0, #APB1ENR]
	ORR R1, R1, #(1 << UART4EN) @ Set bit 19 to enable UART4 clock
	STR R1, [R0, #APB1ENR]
	BX LR


@ Set the baud rate for UART4 using the BRR register
@ BAUD_RATE value is pre-calculated in definitions.s based on the system clock
set_baud_rate:
	LDR R0, =UART4
	MOV R1, #BAUD_RATE
	STR R1, [R0, #UART_BRR]
	BX LR


@ Enable the UART4 control register: UE (bit 0), RE (bit 2), TE (bit 3)
@ 0xD = 0b1101 -> enables the UART, receiver and transmitter
enable_uart_cr1:
	LDR R0, =UART4
	LDR R1, [R0, #UART_CR1]
	ORR R1, R1, #0xD @ Enable UE, RE, TE
	STR R1, [R0, #UART_CR1]
	BX LR


@ ========== Timer 2 Setup ==========

@ Enable the Timer 2 peripheral clock and configure its prescaler and auto-reload value
@ Note: CEN is NOT set here, the timer will be started later in timer.s when needed
enable_timer:
	@ Enable Timer 2 clock on the APB1 bus
	LDR R0, =RCC
	LDR R1, [R0, #APB1ENR]
	ORR R1, R1, #(1 << TIM2EN) @ Set bit 0 to enable Timer 2 clock
	STR R1, [R0, #APB1ENR]

	@ Set the prescaler value (default 7 -> 8MHz / 8 = 1MHz tick rate)
	LDR R0, =TIM2
	MOVW R1, #US_PSC_TIM2
	STRH R1, [R0, #TIM_PSC]

	@ Set the auto-reload value (default 0xFFFFFFFF -> max count for 32-bit TIM2)
	LDR R1, =DEFAULT_ARR_TIM2
	STR R1, [R0, #TIM_ARR]

	@ Force an update event to load PSC and ARR into their shadow registers
	MOV R1, #1
	STR R1, [R0, #TIM_EGR]  @ Set UG bit to generate update event

	@ Clear the UIF flag that gets set as a side effect of UG
	LDR R1, [R0, #TIM_SR]
	BIC R1, R1, #1           @ Clear bit 0 (UIF)
	STR R1, [R0, #TIM_SR]

	BX LR @ return, timer is configured but not yet running
