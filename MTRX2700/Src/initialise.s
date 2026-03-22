.syntax unified
.thumb

#include "definitions.s"

.text
@ define code



@ function to enable the clocks for the peripherals we are using (A, C and E)
enable_gpio_clocks:
	LDR R0, =RCC  @ load the address of the RCC address boundary (for enabling the IO clock)
	LDR R1, [R0, #AHBENR]  @ load the current value of the peripheral clock registers
	ORR R1, R1, #((1 << PA_AHB_OFFSET) | (1 << PC_AHB_OFFSET) | (1 << PE_AHB_OFFSET)) @ Enabling the clock for Port A, C and E
	STR R1, [R0, #AHBENR]  @ store the modified register back to the submodule
	BX LR @ return


@ initialise the discovery board I/O (just outputs: inputs are selected by default)
initialise_io:
	LDR R0, =GPIOE 	@ load the address of the GPIOE register into R0
	LDR R1, [R0, #MODER]

    LDR R2, =0xFFFF0000 @ mask for PE8-15 fields
    BIC R1, R1, R2  @ clear PE8-15

    LDR R2, =0x55550000  @ output (01) for PE8-15
    ORR R1, R1, R2  @ set PE8-15 to output

	STR R1, [R0, #MODER]

	@ Set PC10 and PC11 to Alternate Function mode (MODER = 0b10)
	LDR R0, =GPIOC
	LDR R1, [R0, #MODER]
	BIC R1, R1, #(0xF << 20)   @ Clear bits [23:20] (PC10 and PC11)
	ORR R1, R1, #(0xA << 20)   @ Set 10_10 → AF mode for both pins
	STR R1, [R0, #MODER]

	BX LR @ return from function call


enable_uart:
    PUSH {LR} @ Save the link register address into stack so we can return to main after finsihing setting up UART
    BL set_afrh
    BL enable_high_speed
    BL enable_APB1
    BL set_baud_rate
    BL enable_cr1
    POP {PC} @ Pop the main-returning Link register into PC to jump back to main


set_afrh:
    @ Assign AF5 to PC10 (TX) and PC11 (RX) for UART4
    LDR R0, =GPIOC
    LDR R1, [R0, #AFRH]

    @ Clear 4-bit fields for PC10 [11:8] and PC11 [15:12]
	BIC R1, R1, #(0xFF << AFR10)

    @ Set AF5 (0101) for PC10 and PC11
	ORR R1, R1, #(0x55 << AFR10)
    STR R1, [R0, #AFRH]
    BX LR


enable_high_speed:
    @ Set high speed (0b11) on PC10 and PC11
    LDR R0, =GPIOC
    LDR R1, [R0, #OSPEEDR]

    @ Clear 2-bit fields for PC10 [21:20] and PC11 [23:22]
    BIC R1, R1, #(0xF << OSPEEDR10)

    @ Set high speed (11) for PC10 and PC11
    ORR R1, R1, #(0xF << OSPEEDR10)

    STR R1, [R0, #OSPEEDR]
    BX LR


enable_APB1:
	@ Enable the peripheral clock for UART4
	LDR R0, =RCC
	LDR R1, [R0, #APB1ENR]

	@ Set it to 1
	ORR R1, R1, #(1 << UART4EN) @ bit 19

	STR R1, [R0, #APB1ENR]
	BX LR


set_baud_rate:
	@ Get the address of UART4
	LDR R0, =UART4

	@ Set the baud rate value and store it back to the memory
	MOV R1, #BAUD_RATE
	STR R1, [R0, #BRR]
	BX LR


enable_cr1:
    @ Get the address of UART4
    LDR R0, =UART4
    LDR R1, [R0, #CR1]

    @ Enable UE (bit 0), RE (bit 2), TE (bit 3)
    ORR R1, R1, #0xD

    STR R1, [R0, #CR1]
    BX LR


