.syntax unified
.thumb
.thumb_func

#include "definitions.s"

@ =============================================================
@ Exercise 5 - Board 1 main integration demo
@ =============================================================
@ Behaviour:
@   - Sends a framed "COUNTER = n" packet every 1 second
@   - Waits up to 5 seconds for a framed ACK / NAK reply
@   - ACK         -> increment counter and continue
@   - NAK/timeout -> flash LEDs 3 times and reset counter to 0
@
@ Notes:
@   - Includes a 0.5 s startup delay so both boards can settle
@   - Clears stale UART RX bytes / error flags before each transfer

.equ BOOT_DELAY_MS,   500
.equ ACK_WAIT_MS,     5000
.equ TX_PERIOD_MS,    1000
.equ LED_HALF_PERIOD_MS, 83
.equ MIN_REPLY_LEN,      4
.equ MAX_REPLY_LEN,     16

.data
counter_buf: .ascii "COUNTER = "
             .space 6              @ up to 3 digits + NUL, with extra margin

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
    MOV R0, #7999
    BL timer_set_psc
    BL timer_start

    @ Allow both boards to finish reset / startup.
    LDR R0, =BOOT_DELAY_MS
    BL timer_delay_arr

    @ Clear any stale UART state before the first transaction.
    BL ex5_uart_rx_recover

    MOV R4, #0                      @ counter value

ex5_transmit_loop:
    @ Wait 1 second before sending the next packet.
    LDR R0, =TX_PERIOD_MS
    BL timer_delay_arr

    @ Convert counter value to ASCII at the end of "COUNTER = ".
    LDR R1, =counter_buf
    ADD R1, R1, #10
    MOV R0, R4
    BL int_to_str

    @ Build framed UART packet into tx_buf.
    LDR R0, =counter_buf
    LDR R1, =tx_buf
    BL str_reset_counter
    BL str_concat
    BL str_checksum

    @ Clear stale RX bytes / errors before transmitting.
    BL ex5_uart_rx_recover

    @ Transmit the full packet.
    LDR R1, =tx_buf
    LDRB R2, [R1, #LENGTH_BYTE_IDX]
    BL uart_transmit

    @ Wait for framed ACK / NAK reply.
    BL ex5_wait_ack
    CMP R0, #ACK
    BNE ex5_nak_or_timeout

    @ ACK received.
    ADD R4, R4, #1
    AND R4, R4, #0xFF
    B ex5_transmit_loop

ex5_nak_or_timeout:
    BL ex5_flash_3x
    MOV R4, #0
    B ex5_transmit_loop


@ -------------------------------------------------------------
@ ex5_wait_ack
@ -------------------------------------------------------------
@ Wait up to 5 seconds for a framed ACK / NAK packet.
@   + Output: R0 = ACK / NAK / 0xFF (timeout or malformed)
@   + Modifies: R0, R1, R2, R5, R6
.type ex5_wait_ack, %function
ex5_wait_ack:
    PUSH {R5, R6, LR}

    @ Start a fresh 5 second timeout window on TIM2.
    LDR R5, =TIM2
    LDR R6, =ACK_WAIT_MS
    STR R6, [R5, #TIM_ARR]

    MOV R6, #(1 << TIM_UG)
    STR R6, [R5, #TIM_EGR]

    LDR R6, [R5, #TIM_SR]
    BIC R6, R6, #(1 << TIM_UIF)
    STR R6, [R5, #TIM_SR]

ex5_wait_loop:
    @ Clear receive-side UART errors if they appear while waiting.
    BL ex5_uart_check_and_clear_errors

    @ Check whether a byte has arrived.
    LDR R6, =UART4
    LDR R0, [R6, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BNE ex5_byte_received

    @ Check timeout flag.
    LDR R6, =TIM2
    LDR R0, [R6, #TIM_SR]
    ANDS R0, R0, #(1 << TIM_UIF)
    BNE ex5_timeout

    B ex5_wait_loop

ex5_byte_received:
    @ Phase 1: read STX + length byte.
    LDR R1, =rx_buf
    MOV R2, #2
    BL uart_receive_packet

    @ Basic reply sanity checks before reading the rest.
    LDR R1, =rx_buf
    LDRB R2, [R1]
    CMP R2, #STX
    BNE ex5_bad_reply

    LDRB R2, [R1, #1]
    CMP R2, #MIN_REPLY_LEN
    BLT ex5_bad_reply
    CMP R2, #MAX_REPLY_LEN
    BGT ex5_bad_reply

    @ Phase 2: read the remaining bytes.
    SUBS R2, R2, #2
    ADD R1, R1, #2
    BL uart_receive_packet

    @ ACK / NAK payload byte is at index 2.
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
@ Flash all LEDs 3 times with 0.5 s ON / 0.5 s OFF.
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
@ ex5_uart_rx_recover
@ -------------------------------------------------------------
@ Clear UART receive error flags and flush any stale RX bytes.
@   + Output: none
@   + Modifies: R0, R5, R6
.type ex5_uart_rx_recover, %function
ex5_uart_rx_recover:
    PUSH {R5, R6, LR}
    LDR R5, =UART4

    @ Clear RX error flags if set.
    LDR R0, [R5, #UART_ISR]
    ANDS R6, R0, #((1 << ORE) | (1 << FE) | (1 << NE))
    BEQ ex5_uart_flush_only

    LDR R6, =((1 << ORECF) | (1 << FECF) | (1 << NECF))
    STR R6, [R5, #UART_ICR]

ex5_uart_flush_only:
ex5_uart_flush_loop:
    LDR R0, [R5, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BEQ ex5_uart_rx_recover_done

    LDRB R6, [R5, #UART_RDR]
    B ex5_uart_flush_loop

ex5_uart_rx_recover_done:
    POP {R5, R6, PC}


@ -------------------------------------------------------------
@ ex5_uart_check_and_clear_errors
@ -------------------------------------------------------------
@ Clear UART receive errors during the ACK wait loop.
@ Any pending RX bytes are also flushed.
@   + Output: none
@   + Modifies: R0, R5, R6
.type ex5_uart_check_and_clear_errors, %function
ex5_uart_check_and_clear_errors:
    PUSH {R5, R6, LR}
    LDR R5, =UART4

    LDR R0, [R5, #UART_ISR]
    ANDS R6, R0, #((1 << ORE) | (1 << FE) | (1 << NE))
    BEQ ex5_uart_err_done

    LDR R6, =((1 << ORECF) | (1 << FECF) | (1 << NECF))
    STR R6, [R5, #UART_ICR]

ex5_uart_err_flush:
    LDR R0, [R5, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BEQ ex5_uart_err_done

    LDRB R6, [R5, #UART_RDR]
    B ex5_uart_err_flush

ex5_uart_err_done:
    POP {R5, R6, PC}


@ -------------------------------------------------------------
@ int_to_str
@ -------------------------------------------------------------
@ Convert an unsigned integer to a NUL-terminated ASCII string.
@   + Input:  R0 = value, R1 = destination buffer
@   + Output: destination buffer filled with ASCII digits + NUL
@   + Modifies: R2, R3, R4, R5
.type int_to_str, %function
int_to_str:
    PUSH {R4, R5, LR}

    CMP R0, #0
    BNE int_to_str_extract

    MOV R2, #0x30
    STRB R2, [R1]
    MOV R2, #0
    STRB R2, [R1, #1]
    POP {R4, R5, PC}

int_to_str_extract:
    MOV R3, #0                      @ digit count
    MOV R5, #10

int_to_str_digit_loop:
    UDIV R4, R0, R5
    MLS  R2, R4, R5, R0             @ remainder = R0 - R4*10
    ADD  R2, R2, #0x30              @ convert digit to ASCII
    PUSH {R2}
    ADDS R3, R3, #1
    MOVS R0, R4
    BNE int_to_str_digit_loop

int_to_str_write:
    POP  {R2}
    STRB R2, [R1], #1
    SUBS R3, R3, #1
    BNE int_to_str_write

    MOV R2, #0
    STRB R2, [R1]

    POP {R4, R5, PC}
