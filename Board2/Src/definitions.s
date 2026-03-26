@ =============================================
@ Clock and Bus Settings
@ =============================================
.equ RCC, 0x40021000 @ base address for Reset and Clock Control
.equ AHBENR, 0x14 @ AHB peripheral clock enable register offset
.equ APB1ENR, 0x1C @ APB1 peripheral clock enable register offset


@ =============================================
@ GPIO Common Register Offsets
@ =============================================
.equ MODER, 0x00 @ port mode register
.equ OSPEEDR, 0x08 @ port output speed register
.equ PUPDR, 0x0C @ pull-up/pull-down register
.equ IDR, 0x10 @ input data register
.equ ODR, 0x14 @ output data register
.equ AFRH, 0x24 @ alternate function high register (pins 8-15)
.equ AF5, 0x5 @ alternate function 5 value
.equ PULLUP, 0x1 @ pull-up value (01)


@ =============================================
@ Port A Settings (User Button on PA0)
@ =============================================
.equ GPIOA, 0x48000000 @ base address for GPIOA
.equ PA_AHB_OFFSET, 17 @ bit position in AHBENR for Port A clock
.equ PA1_PUPDR_OFFSET, 2 @ bit position for PA1 in PUPDR (bits [3:2])


@ =============================================
@ Port C Settings (UART4: PC10-TX, PC11-RX)
@ =============================================
.equ GPIOC, 0x48000800 @ base address for GPIOC
.equ PC_AHB_OFFSET, 19 @ bit position in AHBENR for Port C clock
.equ AFR10, 8 @ bit start for pin 10 in AFRH
.equ AFR11, 12 @ bit start for pin 11 in AFRH
.equ OSPEEDR10, 20 @ bit position for PC10 in OSPEEDR (pin10 * 2 = 20)


@ =============================================
@ Port E Settings (LEDs on PE8-PE15)
@ Note: Port E on other boards might be used for different purposes.
@ Check carefully before using Port E code on any board version.
@ =============================================
.equ GPIOE, 0x48001000 @ base address for GPIOE (PE8-15 are the LEDs)
.equ PE8_15, 16 @ bit offset for pins 8-15 when setting pin roles
.equ PE_AHB_OFFSET, 21 @ bit position in AHBENR for Port E clock
.equ LED_PATTERN, 0b01010101 @ default LED pattern for debugging


@ =============================================
@ UART4 Settings
@ =============================================
.equ UART4, 0x40004C00 @ base address for UART4
.equ UART4EN, 19 @ bit position for UART4 clock in APB1ENR
.equ UART_CR1, 0x00 @ control register 1 offset
.equ UART_BRR, 0x0C @ baud rate register offset
.equ UART_ISR, 0x1C @ interrupt and status register offset
.equ UART_TDR, 0x28 @ transmit data register offset
.equ UART_RDR, 0x24 @ receive data register offset
.equ TXE, 7 @ transmit data register empty flag in ISR
.equ RXNE, 5 @ read data register not empty flag in ISR
@ .equ BAUD_RATE, 833 @ 9600 baud at 8MHz (for clock speed demo)
.equ BAUD_RATE, 69 @ 115200 baud at 8MHz
.equ ACK, 0x06 @ acknowledge character
.equ NAK, 0x15 @ negative acknowledge character
.equ TC,        6       @ Transmission complete flag in UART_ISR
.equ TCCF,      6       @ Transmission complete clear flag in UART_ICR
.equ UART_ICR,  0x20
.equ ORE,       3
.equ ORECF,     3


@ =============================================
@ Timer 2 Settings
@ =============================================
.equ TIM2, 0x40000000 @ base address for Timer 2
.equ TIM2EN, 0 @ bit position for Timer 2 in APB1ENR
.equ TIM_CR1, 0x00 @ control register 1 offset
.equ TIM_SR, 0x10 @ status register offset
.equ TIM_EGR, 0x14 @ event generation register offset
.equ TIM_CCER, 0x20 @ capture/compare enable register offset
.equ TIM_CNT, 0x24 @ counter value register offset
.equ TIM_PSC, 0x28 @ prescaler register offset
.equ TIM_ARR, 0x2C @ auto-reload register offset
.equ TIM_CCR1, 0x34 @ capture/compare register 1 offset
.equ TIM_CCR2, 0x38 @ capture/compare register 2 offset

@ CR1 bit fields
.equ TIM_CEN, 0 @ counter enable
.equ TIM_ARPE, 7 @ auto-reload preload enable

@ CCER bit fields
.equ TIM_CC1E, 0 @ output compare channel 1 enable
.equ TIM_CC2E, 4 @ output compare channel 2 enable

@ SR bit fields
.equ TIM_UIF, 0 @ update interrupt flag (CNT overflows ARR)
.equ TIM_CC1F, 1 @ channel 1 compare match flag (CC1IF)
.equ TIM_CC2F, 2 @ channel 2 compare match flag (CC2IF)

@ EGR bit fields
.equ TIM_UG, 0 @ update generation (triggers software update event)

@ Prescaler and timing constants
.equ US_PSC_TIM2, 7 @ 8MHz / (7+1) = 1MHz = 1us per tick
.equ DEFAULT_ARR_TIM2, 0xFFFFFFFF @ max count for 32-bit TIM2

@ Blink half-periods in ms (actual freq = 1 / (2 * value * tick_period))
@ These assume PSC = 7999 giving a 1ms tick
.equ LED1_HALF_PERIOD, 500 @ 1Hz blink (500ms on, 500ms off)
.equ LED2_HALF_PERIOD, 100 @ 5Hz blink (100ms on, 100ms off)


@ =============================================
@ CRC16-CCITT Constants
@ =============================================
.equ CRC16_POLY, 0x1021 @ CRC16-CCITT polynomial (x^16 + x^12 + x^5 + 1)
.equ CRC16_INIT, 0xFFFF @ initial CRC value


@ =============================================
@ String Constants
@ =============================================
.equ MIN_LOWER_CASE, 0x61 @ 'a'
.equ MAX_LOWER_CASE, 0x7A @ 'z'
.equ MIN_UPPER_CASE, 0x41 @ 'A'
.equ MAX_UPPER_CASE, 0x5A @ 'Z'
.equ STX, 0x02 @ start of text (packet framing)
.equ ETX, 0x03 @ end of text (packet framing)
.equ UART_OVERHEAD, 3 @ overhead bytes: STX + length + ETX
.equ UART_BODY_OFFSET, 2 @ body starts at index 2: [STX][Len][Body...]
.equ LENGTH_BYTE_IDX, 1 @ length byte is at index 1


@ =============================================
@ Button Constants
@ =============================================
.equ TASK_MODE_ONCE, 0 @ execute task once per button tap (press + release)
.equ TASK_MODE_HOLD, 1 @ execute task continuously while button is held
