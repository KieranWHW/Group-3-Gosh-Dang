@ Basic Register and clock settings
.equ RCC, 0x40021000 @ Address for Reset and Clock Control Register
.equ AHBENR, 0x14 @ Enabling Advance-High Performance Bus
.equ APB1ENR, 0x1C @ Enabling Periphal Clock
.equ AFRH, 0x24 @ Enabling Alternation functions on GPIO 8-15
.equ MODER, 0x00	@ Set the mode for the GPIO
.equ OSPEEDR, 0x08	@ Set the speed for the GPIO
.equ AF5, 0x5 @ Alternate function constants
.equ IDR, 0x10 @ GPIO input data register
.equ ODR, 0x14 @ GPIO output data register
.equ PUPDR, 0x0C @ GPIO pull-up/pull-down register offset
.equ PULLUP, 0x1 @ Pull-up value (01)


@ UART constants
.equ UART4, 0x40004C00 @ Base address for UART4
.equ UART4EN, 19 @ bit position for enabling UART4 peripheral clock
.equ BRR, 0x0C @ Address offset for the baud rate setting register
.equ ISR, 0x1C @ Address offset for the interrupt and status register
@ .equ BAUD_RATE, 833 @ For demonstrating we can change clock speed, use 9600 baud rate, this is calculated usign 8MHz Clock
.equ BAUD_RATE, 69 @ Use 115200 baud rate, this is calculated using 8 Mhz clock
.equ CR1, 0x00 @ Address offset of the control register 1
.equ TDR, 0x28 @ Address offset of transmit data register
.equ RDR, 0x24 @ Address offset of read data register
.equ TXE, 7 @ Bit offset for the Transmit data register empty in ISR
.equ RXNE, 5 @ Bit offset for the Read data register not empty in ISR
.equ ACK, 0x06 @ Hex value for ACK
.equ NAK, 0x15 @ Hex value for NAK


@ String constants
.equ MIN_LOWER_CASE, 0x61 @ Minimum hex value of a lower case character (a)
.equ MAX_LOWER_CASE, 0x7A @ Maximum hex value of a lower case character (z)
.equ MIN_UPPER_CASE, 0x41 @ Minimum hex value of a upper case character (A)
.equ MAX_UPPER_CASE, 0x5A @ Maximum hex value of a upper case character (Z)
.equ STX, 0x02 @ Hex value of the starting character in UART comm
.equ ETX, 0x03 @ Hex value of the ending character in UART comm
.equ UART_OVERHEAD, 3 @ Total overhead bytes added to packet: STX + Length byte + ETX
.equ UART_BODY_OFFSET, 2 @ String body starts 2 bytes into buffer: [STX][Length][String Body...][ETX]
.equ LENGTH_BYTE_IDX, 1 @ Index of the length byte in the buffer: [STX][Length byte here][...]


@ Button constants
.equ TASK_MODE_ONCE, 0     @ Execute task once per button tap (press + release)
.equ TASK_MODE_HOLD, 1     @ Execute task continuously while button is he


@ Port A settings
@ Port A will primarly be used to read the User Input Button (PA0)
.equ GPIOA, 0x48000000	@ base register for GPIOA
.equ PA_AHB_OFFSET, 17 @ The bit position in the AHBENR for enabling port A bus
.equ PA1_PUPDR_OFFSET, 2 @ Bit position for PA1 in PUPDR (bits [3:2])


@ Port C settings
@ This port will primarly be used for UART communications (UART4: PC10-TX and PC11-RX)
.equ GPIOC, 0x48000800	@ base register for GPIOA (pa0 is the button)
.equ PC_AHB_OFFSET, 19 @ The bit position in the AHBENR for enabling port C bus
.equ AFR10, 8 @ The bit starting position for pin 10 in AFRH
.equ AFR11, 12 @ The bit starting position for pin 11 in AFRH
.equ OSPEEDR10, 20 @ bit position for PC10 in OSPEEDR (2 bits per pin, so pin10 = 10*2 = 20)


@ Port E Settings
@ This port will primarly be used for LEDs control on the STM32F3DISCOVERY Board
@ Attention: Port E on other port might be used for different purpose. Please check carefully before using
@ Port E code on any board version.
.equ GPIOE, 0x48001000	@ base register for GPIOE (pe8-15 are the LEDs)
.equ PE8_15, 16 @ Bit offset for pin 8-15 when setting pins' roles
.equ PE_AHB_OFFSET, 21 @ The bit position in the AHBENR for enabling port E bus
.equ LED_PATTERN, 0b01010101 @ Default Led Pattern for debugging
