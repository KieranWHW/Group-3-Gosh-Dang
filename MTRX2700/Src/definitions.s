@ =============================================
@ Clock and Bus Settings
@ =============================================
.equ RCC, 0x40021000 @ Address for Reset and Clock Control Register
.equ AHBENR, 0x14 @ AHB peripheral clock enable register offset
.equ APB1ENR, 0x1C @ APB1 peripheral clock enable register offset


@ =============================================
@ GPIO Common Register Offsets
@ =============================================
.equ MODER, 0x00 @ GPIO port mode register offset
.equ OSPEEDR, 0x08 @ GPIO port output speed register offset
.equ PUPDR, 0x0C @ GPIO pull-up/pull-down register offset
.equ IDR, 0x10 @ GPIO input data register offset
.equ ODR, 0x14 @ GPIO output data register offset
.equ AFRH, 0x24 @ GPIO alternate function high register offset (pins 8-15)
.equ AF5, 0x5 @ Alternate function 5 value
.equ PULLUP, 0x1 @ Pull-up value (01)


@ =============================================
@ Port A Settings (User Input Button on PA0)
@ =============================================
.equ GPIOA, 0x48000000 @ Base register for GPIOA
.equ PA_AHB_OFFSET, 17 @ Bit position in AHBENR for enabling Port A clock
.equ PA1_PUPDR_OFFSET, 2 @ Bit position for PA1 in PUPDR (bits [3:2])


@ =============================================
@ Port C Settings (UART4: PC10-TX, PC11-RX)
@ =============================================
.equ GPIOC, 0x48000800 @ Base register for GPIOC
.equ PC_AHB_OFFSET, 19 @ Bit position in AHBENR for enabling Port C clock
.equ AFR10, 8 @ Bit starting position for pin 10 in AFRH
.equ AFR11, 12 @ Bit starting position for pin 11 in AFRH
.equ OSPEEDR10, 20 @ Bit position for PC10 in OSPEEDR (2 bits per pin, pin10 = 10*2 = 20)


@ =============================================
@ Port E Settings (LEDs on PE8-PE15)
@ Note: Port E on other boards might be used for different purposes.
@ Please check carefully before using Port E code on any board version.
@ =============================================
.equ GPIOE, 0x48001000 @ Base register for GPIOE (PE8-15 are the LEDs)
.equ PE8_15, 16 @ Bit offset for pins 8-15 when setting pin roles
.equ PE_AHB_OFFSET, 21 @ Bit position in AHBENR for enabling Port E clock
.equ LED_PATTERN, 0b01010101 @ Default LED pattern for debugging


@ =============================================
@ UART4 Settings
@ =============================================
.equ UART4, 0x40004C00 @ Base address for UART4
.equ UART4EN, 19 @ Bit position for enabling UART4 clock in APB1ENR
.equ UART_CR1, 0x00 @ UART control register 1 offset
.equ UART_BRR, 0x0C @ UART baud rate register offset
.equ UART_ISR, 0x1C @ UART interrupt and status register offset
.equ UART_TDR, 0x28 @ UART transmit data register offset
.equ UART_RDR, 0x24 @ UART receive data register offset
.equ TXE, 7 @ Bit offset for Transmit Data Register Empty in ISR
.equ RXNE, 5 @ Bit offset for Read Data Register Not Empty in ISR
@ .equ BAUD_RATE, 833 @ 9600 baud rate calculated using 8MHz clock (for clock speed demo)
.equ BAUD_RATE, 69 @ 115200 baud rate calculated using 8MHz clock
.equ ACK, 0x06 @ Hex value for ACK
.equ NAK, 0x15 @ Hex value for NAK


@ =============================================
@ Timer 2 Settings
@ =============================================
.equ TIM2, 0x40000000 @ Base address for Timer 2
.equ TIM2EN, 0 @ Bit position for enabling Timer 2 in APB1ENR
.equ TIM_CR1, 0x00 @ Timer control register 1 offset
.equ TIM_SR, 0x10 @ Timer status register offset
.equ TIM_CCER, 0x20 @ Timer capture/compare enable register offset
.equ TIM_CNT, 0x24 @ Timer counter value register offset
.equ TIM_PSC, 0x28 @ Timer prescaler register offset
.equ TIM_ARR, 0x2C @ Timer auto-reload register offset
.equ TIM_CCR1, 0x34 @ Timer capture/compare register 1 offset
.equ TIM_CCR2, 0x38 @ Timer capture/compare register 2 offset
.equ TIM_CEN, 0 @ Bit position for enabling counting in CR1
.equ TIM_CC1E, 0 @ Bit position for enabling output compare channel 1 in CCER
.equ TIM_CC2E, 4 @ Bit position for enabling output compare channel 2 in CCER
.equ TIM_CC1F, 1 @ Bit position for channel 1 compare match flag in SR (CC1IF)
.equ TIM_CC2F, 2 @ Bit position for channel 2 compare match flag in SR (CC2IF)
.equ US_PSC_TIM2, 7 @ Microsecond prescaler: 8MHz / (7+1) = 1MHz = 1us per tick
.equ DEFAULT_ARR_TIM2, 0xFFFFFFFF @ Default auto-reload: max count for TIM2 (32-bit)
.equ TIM_EGR, 0x14 @ Timer event generation register offset
.equ TIM_UG, 0   @ Bit 0 of EGR: triggers a software update event
.equ TIM_ARPE, 7    @ Bit 7 of CR1: Auto-reload preload enable
.equ TIM_UIF,  0    @ Bit 0 of SR: Update interrupt flag (fires when CNT overflows ARR)
@ Blink half-periods in ms ticks (actual frequency = 1 / (2 × value × TICK_MS))
.equ LED1_HALF_PERIOD,  500  @ 1Hz blink  (500ms on, 500ms off), assuming using 1ms delay period (7999 PSC)
.equ LED2_HALF_PERIOD,  100  @ 5Hz blink  (100ms on, 100ms off), assuming using 1ms delay period (7999 PSC)



@ =============================================
@ String Constants
@ =============================================
.equ MIN_LOWER_CASE, 0x61 @ Minimum hex value of a lower case character (a)
.equ MAX_LOWER_CASE, 0x7A @ Maximum hex value of a lower case character (z)
.equ MIN_UPPER_CASE, 0x41 @ Minimum hex value of an upper case character (A)
.equ MAX_UPPER_CASE, 0x5A @ Maximum hex value of an upper case character (Z)
.equ STX, 0x02 @ Start of text character for UART packet framing
.equ ETX, 0x03 @ End of text character for UART packet framing
.equ UART_OVERHEAD, 3 @ Total overhead bytes: STX + Length byte + ETX
.equ UART_BODY_OFFSET, 2 @ String body starts 2 bytes into buffer: [STX][Length][Body...][ETX]
.equ LENGTH_BYTE_IDX, 1 @ Index of the length byte: [STX][Length byte here][...]


@ =============================================
@ Button Constants
@ =============================================
.equ TASK_MODE_ONCE, 0 @ Execute task once per button tap (press + release)
.equ TASK_MODE_HOLD, 1 @ Execute task continuously while button is held
