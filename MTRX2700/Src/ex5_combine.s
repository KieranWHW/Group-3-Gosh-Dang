.syntax unified
.thumb
.thumb_func

#include "definitions.s"

@ =============================================================
@ Exercise 5 - Board 1: transmitter / counter
@ =============================================================
@ Behaviour:
@   - Sends a framed "COUNTER = n" packet every 1 second
@   - Waits up to 5 seconds for a framed ACK / NAK reply
@   - ACK         -> increment counter and continue
@   - NAK/timeout -> flash LEDs 3 times and reset counter to 0
@
@ Notes:
@   - 500 ms startup delay so both boards can settle before
@     the first transmission
@   - Stale UART RX bytes and error flags are cleared before
@     every transmission to prevent ORE lockups

@ Set to 1 to use CRC16-CCITT checksum (bonus task),
@ set to 0 to use BCC XOR checksum (original).
@ Both boards must use the same value.
.equ USE_CRC16, 1

.equ BOOT_DELAY_MS, 500
.equ TX_PERIOD_MS, 1000
.equ ACK_WAIT_MS,  5000 @ 5s waiting for response
.equ LED_HALF_PERIOD_MS, 500  @ 0.5 s ON / 0.5 s OFF per spec

.data
@ "COUNTER = " prefix with room for up to 3 digits + NUL
counter_buf: .ascii "COUNTER = "
             .space 6

tx_buf:      .space 32
rx_buf:      .space 32

.text


@ -------------------------------------------------------------
@ ex5_run_demo
@ -------------------------------------------------------------
@ Main loop for Board 1.
@   + Output: none
@   + Modifies: R0, R1, R2, R4
.type ex5_run_demo, %function
ex5_run_demo:
    @ Prescaler: 7999 -> 1 MHz tick (8 MHz / 8000 = 1 us resolution)
    MOV R0, #7999
    BL timer_set_psc
    BL timer_start

    @ Let both boards finish reset / boot before first TX
    LDR R0, =BOOT_DELAY_MS
    BL timer_delay_arr

    MOV R4, #0 @ counter value (0-255, wraps)

ex5_transmit_loop:
    @ Wait 1 second between packets
    LDR R0, =TX_PERIOD_MS
    BL timer_delay_arr

    @ Write ASCII digits for current counter into counter_buf+10
    LDR R1, =counter_buf
    ADD R1, R1, #10
    MOV R0, R4
    BL int_to_str

    @ Frame the full string then append checksum (algorithm selected at build time)
    LDR R0, =counter_buf
    LDR R1, =tx_buf
    BL str_reset_counter
    BL str_concat
.if USE_CRC16
    BL str_crc16_checksum           @ CRC16-CCITT: appends 2 bytes
.else
    BL str_checksum                 @ BCC XOR: appends 1 byte
.endif

    @ Flush any stale bytes, clear ORE before transmitting
    BL ex5_uart_clear_errors

    @ Transmit the packet; length is stored at the LENGTH_BYTE_IDX offset
    LDR R1, =tx_buf
    LDRB R2, [R1, #LENGTH_BYTE_IDX]
    BL uart_transmit

    @ Poll for ACK / NAK within the 5-second window
    BL ex5_wait_ack
    CMP R0, #ACK
    BNE ex5_nak_or_timeout

    @ ACK received: increment the counter (wraps at 256)
    ADD R4, R4, #1
    AND R4, R4, #0xFF
    B ex5_transmit_loop

ex5_nak_or_timeout:
    @ NAK or timeout: visual alert and reset counter
    BL ex5_flash_3x
    MOV R4, #0
    B ex5_transmit_loop


@ -------------------------------------------------------------
@ ex5_wait_ack
@ -------------------------------------------------------------
@ Wait up to 5 seconds for a framed ACK / NAK packet on UART4.
@ The timeout window is started fresh from TIM2 each call.
@   + Output: R0 = ACK / NAK byte, or 0xFF on timeout / bad reply
@   + Modifies: R0, R1, R2, R5, R6
.type ex5_wait_ack, %function
ex5_wait_ack:
    PUSH {R5, R6, LR}

    @ Reload TIM2 ARR with the timeout window and force an
    @ update event so the new value takes effect immediately
    LDR R5, =TIM2
    LDR R6, =ACK_WAIT_MS
    STR R6, [R5, #TIM_ARR]

	@ Re-initialize the windows so we get a correct 5s-window
    MOV R6, #(1 << TIM_UG)
    STR R6, [R5, #TIM_EGR]

    LDR R6, [R5, #TIM_SR]
    BIC R6, R6, #(1 << TIM_UIF) @ clear stale update flag
    STR R6, [R5, #TIM_SR]

ex5_wait_loop:
    @ Check whether a byte has arrived on UART4
    LDR R6, =UART4
    LDR R0, [R6, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BNE ex5_byte_received

    @ Check whether the 5-second timeout has elapsed
    LDR R6, =TIM2
    LDR R0, [R6, #TIM_SR]
    ANDS R0, R0, #(1 << TIM_UIF)
    BNE ex5_timeout

    B ex5_wait_loop

ex5_byte_received:
    @ Phase 1: read STX + length byte
    LDR R1, =rx_buf
    MOV R2, #2
    BL uart_receive_packet

    @ Sanity-check header before committing to reading the rest
    LDR R1, =rx_buf
    LDRB R2, [R1]
    CMP R2, #STX
    BNE ex5_bad_reply

    LDRB R2, [R1, #1]
.if USE_CRC16
    CMP R2, #5    @ minimum CRC16 reply: STX LEN ACK NUL ETX CRC_HI CRC_LO = 7, floor at 5
.else
    CMP R2, #4    @ minimum BCC reply: STX LEN ACK NUL ETX CS = 6, floor at 4
.endif
    BLT ex5_bad_reply
    CMP R2, #16  @ sanity upper bound
    BGT ex5_bad_reply

    @ Phase 2: read the remaining (LEN - 2) bytes
    SUBS R2, R2, #2
    ADD R1, R1, #2
    BL uart_receive_packet

    @ The ACK / NAK payload byte sits at index 2 of rx_buf
    LDR R1, =rx_buf
    LDRB R0, [R1, #2]
    POP {R5, R6, PC}

ex5_bad_reply:
    MOV R0, #0xFF
    POP {R5, R6, PC}

ex5_timeout:
    MOV R0, #0xFF
    POP {R5, R6, PC}


@ -------------------------------------------------------------
@ ex5_flash_3x
@ -------------------------------------------------------------
@ Flash all LEDs 3 times: 0.5 s ON then 0.5 s OFF each cycle.
@   + Output: none
@   + Modifies: R0, R5, R7
.type ex5_flash_3x, %function
ex5_flash_3x:
    PUSH {R5, R7, LR}
    MOV R5, #3

ex5_flash_loop:
    MOV R7, #0xFF
    BL led_set_pattern
    LDR R0, =LED_HALF_PERIOD_MS
    BL timer_delay_arr

    MOV R7, #0x00
    BL led_set_pattern
    LDR R0, =LED_HALF_PERIOD_MS
    BL timer_delay_arr

    SUBS R5, R5, #1
    BNE ex5_flash_loop

    POP {R5, R7, PC}


@ -------------------------------------------------------------
@ ex5_uart_clear_errors
@ -------------------------------------------------------------
@ Clear UART4 receive error flags and flush any stale RX bytes.
@ Call this before every receive window to prevent ORE lockups.
@   + Output: none
@   + Modifies: R0, R5, R6
.type ex5_uart_clear_errors, %function
ex5_uart_clear_errors:
    PUSH {R5, R6, LR}
    LDR R5, =UART4

    @ Check for overrun error (ORE) and clear it via ICR if set
    LDR R0, [R5, #UART_ISR]
    ANDS R6, R0, #(1 << ORE)
    BEQ ex5_uart_clear_rxne

    LDR R6, =(1 << ORECF)
    STR R6, [R5, #UART_ICR]

ex5_uart_clear_rxne:
    @ Drain any bytes already sitting in RDR (clears RXNE)
    LDR R0, [R5, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BEQ ex5_uart_rx_cleared

    LDRB R6, [R5, #UART_RDR]
    B ex5_uart_clear_rxne

ex5_uart_rx_cleared:
    POP {R5, R6, PC}


@ -------------------------------------------------------------
@ int_to_str
@ -------------------------------------------------------------
@ Convert an unsigned integer to a NUL-terminated ASCII string.
@ Uses a stack-based digit reversal so no extra buffer is needed.
@   + Input:  R0 = value (unsigned), R1 = destination buffer
@   + Output: buffer filled with ASCII decimal digits + NUL
@   + Modifies: R2, R3, R4, R5
.type int_to_str, %function
int_to_str:
    PUSH {R4, R5, LR}

    @ Special case: value is 0
    CMP R0, #0
    BNE int_to_str_extract

    MOV R2, #0x30                   @ '0'
    STRB R2, [R1]
    MOV R2, #0
    STRB R2, [R1, #1]
    POP {R4, R5, PC}

int_to_str_extract:
    MOV R3, #0                      @ digit count
    MOV R5, #10

int_to_str_digit_loop:
    @ Divide by 10; remainder is the next digit (least-significant first)
    UDIV R4, R0, R5
    MLS  R2, R4, R5, R0             @ R2 = R0 - (R0/10)*10
    ADD  R2, R2, #0x30              @ convert to ASCII digit
    PUSH {R2}
    ADDS R3, R3, #1
    MOVS R0, R4
    BNE int_to_str_digit_loop

int_to_str_write:
    @ Pop digits off the stack in reverse (most-significant first)
    POP  {R2}
    STRB R2, [R1], #1
    SUBS R3, R3, #1
    BNE int_to_str_write

    MOV R2, #0
    STRB R2, [R1]                   @ NUL terminator

    POP {R4, R5, PC}
