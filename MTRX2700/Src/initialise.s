.syntax unified
.thumb

#include "definitions.s"

.text
@ define code


@ ========== GPIO Clock Setup ==========

@ Enable the clocks for GPIO peripherals we are using (Port A, C and E)
@   + Input: None
@   + Output: None, clocks enabled for GPIOA, GPIOC and GPIOE
@   + Modifies: R0, R1
enable_gpio_clocks:
	LDR R0, =RCC
	LDR R1, [R0, #AHBENR]
	ORR R1, R1, #((1 << PA_AHB_OFFSET) | (1 << PC_AHB_OFFSET) | (1 << PE_AHB_OFFSET))
	STR R1, [R0, #AHBENR]
	BX LR


@ ========== GPIO Pin Mode Setup ==========

@ Set pin modes for LEDs and UART
@ PE8-PE15 = output (LEDs), PC10-PC11 = alternate function (UART4)
@ PA0 is input by default so no setup needed for the button
@   + Input: None
@   + Output: None, pin modes configured
@   + Modifies: R0, R1, R2
initialise_io:
	@ Configure PE8-PE15 as general purpose output for driving LEDs
	LDR R0, =GPIOE
	LDR R1, [R0, #MODER]
	LDR R2, =0xFFFF0000 @ mask for PE8-15 mode fields (2 bits per pin)
	BIC R1, R1, R2 @ clear PE8-15 mode bits
	LDR R2, =0x55550000 @ output mode (01) for PE8-15
	ORR R1, R1, R2
	STR R1, [R0, #MODER]

	@ Configure PC10 and PC11 to alternate function mode for UART4
	LDR R0, =GPIOC
	LDR R1, [R0, #MODER]
	BIC R1, R1, #(0xF << 20) @ clear bits [23:20] for PC10 and PC11
	ORR R1, R1, #(0xA << 20) @ set 10_10 = AF mode for both pins
	STR R1, [R0, #MODER]

	@ Configure PA1 as pull-up for gpio_do_task_pa0 exit input.
	@ Active-low: PA1 reads HIGH when floating, LOW only when driven to GND.
	@ This means disconnecting the wire reliably releases the pin HIGH.
    LDR R0, =GPIOA
    LDR R1, [R0, #PUPDR]
    BIC R1, R1, #(0x3 << PA1_PUPDR_OFFSET)
    ORR R1, R1, #(0x1 << PA1_PUPDR_OFFSET)   @ 01 = pull-up
    STR R1, [R0, #PUPDR]

	BX LR


@ ========== UART4 Setup ==========

@ Fully initialise UART4 on PC10 (TX) and PC11 (RX)
@ Calls each sub-step in order: pin function, speed, clock, baud rate, control register
@   + Input: None
@   + Output: None, UART4 is ready to transmit and receive
@   + Modifies: R0, R1
enable_uart:
	PUSH {LR}
	BL set_afrh
	BL enable_high_speed
	BL enable_uart_clock
	BL set_baud_rate
	BL enable_uart_cr1
	POP {PC}


@ Assign alternate function 5 (UART4) to PC10 (TX) and PC11 (RX)
@   + Input: None
@   + Output: None
@   + Modifies: R0, R1
set_afrh:
	LDR R0, =GPIOC
	LDR R1, [R0, #AFRH]
	BIC R1, R1, #(0xFF << AFR10) @ clear AF fields for PC10 [11:8] and PC11 [15:12]
	ORR R1, R1, #(0x55 << AFR10) @ set AF5 for both pins
	STR R1, [R0, #AFRH]
	BX LR


@ Set PC10 and PC11 to high speed for reliable UART at higher baud rates
@   + Input: None
@   + Output: None
@   + Modifies: R0, R1
enable_high_speed:
	LDR R0, =GPIOC
	LDR R1, [R0, #OSPEEDR]
	BIC R1, R1, #(0xF << OSPEEDR10) @ clear speed fields for PC10 and PC11
	ORR R1, R1, #(0xF << OSPEEDR10) @ set high speed (11) for both pins
	STR R1, [R0, #OSPEEDR]
	BX LR


@ Enable the peripheral clock for UART4 on the APB1 bus
@   + Input: None
@   + Output: None
@   + Modifies: R0, R1
enable_uart_clock:
	LDR R0, =RCC
	LDR R1, [R0, #APB1ENR]
	ORR R1, R1, #(1 << UART4EN) @ bit 19 enables UART4
	STR R1, [R0, #APB1ENR]
	BX LR


@ Set the baud rate for UART4 using the BRR register
@ BAUD_RATE value is pre-calculated in definitions.s based on the system clock
@   + Input: None
@   + Output: None
@   + Modifies: R0, R1
set_baud_rate:
	LDR R0, =UART4
	MOV R1, #BAUD_RATE
	STR R1, [R0, #UART_BRR]
	BX LR


@ Enable UART4 control register: UE (bit 0), RE (bit 2), TE (bit 3)
@ 0xD = 0b1101 enables the UART module, receiver and transmitter
@   + Input: None
@   + Output: None
@   + Modifies: R0, R1
enable_uart_cr1:
	LDR R0, =UART4
	LDR R1, [R0, #UART_CR1]
	ORR R1, R1, #0xD @ enable UE, RE, TE
	STR R1, [R0, #UART_CR1]
	BX LR


@ ========== Timer 2 Setup ==========

@ Enable Timer 2 peripheral clock and configure its prescaler and auto-reload
@ CEN is NOT set here — the timer starts later via timer_start when needed
@   + Input: None
@   + Output: None, Timer 2 is configured but not yet running
@   + Modifies: R0, R1
enable_timer:
	@ Enable Timer 2 clock on the APB1 bus
	LDR R0, =RCC
	LDR R1, [R0, #APB1ENR]
	ORR R1, R1, #(1 << TIM2EN)
	STR R1, [R0, #APB1ENR]

	@ Set prescaler (default 7 -> 8MHz / 8 = 1MHz = 1us per tick)
	LDR R0, =TIM2
	MOVW R1, #US_PSC_TIM2
	STRH R1, [R0, #TIM_PSC]

	@ Set auto-reload to max count for 32-bit TIM2
	LDR R1, =DEFAULT_ARR_TIM2
	STR R1, [R0, #TIM_ARR]

	@ Force update event to load PSC and ARR into their shadow registers
	MOV R1, #1
	STR R1, [R0, #TIM_EGR]

	@ Clear UIF flag that gets set as a side effect of UG
	LDR R1, [R0, #TIM_SR]
	BIC R1, R1, #(1 << TIM_UIF)
	STR R1, [R0, #TIM_SR]

	BX LR



@ Switch system clock from HSI (8MHz) to PLL (36MHz via HSI/2 × 9)
@ Then update UART4 BRR so baud rate stays correct at the new clock
@   + Input:  None
@   + Output: None
@   + Modifies: R0, R1
enable_pll:
    PUSH {LR}
    LDR R0, =RCC

    @ Configure PLL: source = HSI/2, multiplier = ×9 (→ 36MHz)
    LDR R1, [R0, #RCC_CFGR]
    BIC R1, R1, #(0xF << PLLMUL)       @ clear old multiplier bits [21:18]
    ORR R1, R1, #(PLLMUL_X9 << PLLMUL) @ set ×9
    BIC R1, R1, #(1 << PLLSRC)         @ source = HSI/2 (bit 16 = 0)
    STR R1, [R0, #RCC_CFGR]

    @ Turn PLL on
    LDR R1, [R0, #RCC_CR]
    ORR R1, R1, #(1 << PLLON)
    STR R1, [R0, #RCC_CR]

    @ Wait until PLL is locked (PLLRDY = 1)
wait_pll:
    LDR R1, [R0, #RCC_CR]
    TST R1, #(1 << PLLRDY)
    BEQ wait_pll

    @ Switch system clock to PLL (SW = 10)
    LDR R1, [R0, #RCC_CFGR]
    BIC R1, R1, #(0x3 << SW)           @ clear SW bits
    ORR R1, R1, #(0x2 << SW)           @ 10 = PLL selected
    STR R1, [R0, #RCC_CFGR]

    @ Wait until the switch is confirmed (SWS = 10)
wait_sws:
    LDR R1, [R0, #RCC_CFGR]
    AND R1, R1, #(0x3 << SWS)
    CMP R1, #(0x2 << SWS)
    BNE wait_sws

    @ Step 6 — update BRR for the new clock (36MHz / 115200 = 312)
    LDR R0, =UART4
    MOV R1, #BRR_PLL_115200
    STR R1, [R0, #UART_BRR]

    POP {PC}
