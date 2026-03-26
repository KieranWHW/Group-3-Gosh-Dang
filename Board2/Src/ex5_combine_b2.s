.syntax unified
.thumb
.thumb_func

#include "definitions.s"

@ =============================================================
@ Exercise 5 - Board 2: receiver / validator
@ =============================================================
@ Behaviour:
@   - Wait for a framed counter packet from Board 1
@   - Validate structure (STX, LEN, NUL, ETX), checksum,
@     "COUNTER = " prefix, and that the payload is all digits
@   - Display the counter value on the LEDs
@   - Send a framed ACK on success, framed NAK on failure
@   - Flash LEDs 3 times at 0.5 s on NAK
@
@ Notes:
@   - UART errors and stale bytes are drained at the top of
@     every receive loop to prevent ORE lockups after bad packets

@ Set to 1 to use CRC16-CCITT checksum (bonus task),
@ set to 0 to use BCC XOR checksum (original).
@ Both boards must use the same value as ex5_combine.s.
.equ USE_CRC16, 1

.equ STARTUP_DELAY_MS,    500
.equ LED_HALF_PERIOD_MS,  500      @ 0.5 s ON / 0.5 s OFF per spec

@ Minimum counter packet length depends on checksum size:
@   BCC:   STX LEN "COUNTER = X" NUL ETX CS      = 16 bytes
@   CRC16: STX LEN "COUNTER = X" NUL ETX CH CL   = 17 bytes
.if USE_CRC16
.equ MIN_COUNTER_PKT_LEN, 17
.else
.equ MIN_COUNTER_PKT_LEN, 16
.endif

.equ MAX_COUNTER_PKT_LEN, 32

.data
rx_buf:         .space 32
body_buf:       .space 32
resp_src_b2:    .space 2           @ single-byte payload + NUL for str_concat
resp_buf_b2:    .space 16
counter_prefix: .asciz "COUNTER = "

.text


@ -------------------------------------------------------------
@ ex5_board2_run_demo
@ -------------------------------------------------------------
@ Main loop for Board 2.
@   + Output: none
@   + Modifies: R0, R1, R2, R6, R7
.type ex5_board2_run_demo, %function
ex5_board2_run_demo:
    @ Prescaler: 7999 -> 1 MHz tick (8 MHz / 8000 = 1 us resolution)
    LDR R0, =7999
    BL timer_set_psc
    BL timer_start

    @ Optional startup settle delay
    LDR R0, =STARTUP_DELAY_MS
    BL timer_delay_arr

    MOV R7, #0
    BL led_set_pattern

ex5_b2_loop:
    @ Drain stale bytes / clear ORE before listening for a new packet.
    @ Without this, a previous bad receive can leave ORE or residual
    @ bytes in the FIFO, causing the board to immediately re-enter the
    @ invalid path and appear "stuck" after sending a NAK.
    BL ex5_b2_uart_clear_errors

    LDR R6, =UART4

ex5_b2_wait_rxne:
    LDR R0, [R6, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BEQ ex5_b2_wait_rxne

    @ Phase 1: receive STX + length byte
    LDR R1, =rx_buf
    MOV R2, #2
    BL uart_receive_packet

    @ Quick sanity check on header before reading the rest
    LDR R1, =rx_buf
    LDRB R2, [R1]
    CMP R2, #STX
    BNE ex5_b2_invalid

    LDRB R2, [R1, #1]
    CMP R2, #MIN_COUNTER_PKT_LEN
    BLT ex5_b2_invalid
    CMP R2, #MAX_COUNTER_PKT_LEN
    BGT ex5_b2_invalid

    @ Phase 2: receive remaining (LEN - 2) bytes
    SUBS R2, R2, #2
    ADD R1, R1, #2
    BL uart_receive_packet

    @ Full structural + checksum + content validation
    BL ex5_b2_validate_counter_packet
    CMP R0, #1
    BNE ex5_b2_invalid

    @ Valid packet: parse the decimal digits after "COUNTER = "
    LDR R1, =body_buf
    ADD R1, R1, #10
    BL str_to_int

    @ Display the low 8 bits of the counter on the LEDs
    AND R7, R0, #0xFF
    BL led_set_pattern

    MOV R0, #ACK
    BL ex5_b2_send_framed_reply
    B ex5_b2_loop

ex5_b2_invalid:
    @ Send NAK then flash; loop top clears UART state before next RX
    MOV R0, #NAK
    BL ex5_b2_send_framed_reply
    BL ex5_b2_flash_3x
    B ex5_b2_loop


@ -------------------------------------------------------------
@ ex5_b2_uart_clear_errors
@ -------------------------------------------------------------
@ Clear UART4 receive error flags and flush any stale RX bytes.
@ Call at the top of every receive loop to prevent ORE lockups.
@   + Output: none
@   + Modifies: R0, R5, R6
.type ex5_b2_uart_clear_errors, %function
ex5_b2_uart_clear_errors:
    PUSH {R5, R6, LR}
    LDR R5, =UART4

    @ Check for overrun error (ORE) and clear via ICR if set
    LDR R0, [R5, #UART_ISR]
    ANDS R6, R0, #(1 << ORE)
    BEQ ex5_b2_uart_clear_rxne

    LDR R6, =(1 << ORECF)
    STR R6, [R5, #UART_ICR]

ex5_b2_uart_clear_rxne:
    @ Drain any bytes already sitting in RDR (clears RXNE flag)
    LDR R0, [R5, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BEQ ex5_b2_uart_rx_cleared

    LDRB R6, [R5, #UART_RDR]
    B ex5_b2_uart_clear_rxne

ex5_b2_uart_rx_cleared:
    POP {R5, R6, PC}


@ -------------------------------------------------------------
@ ex5_b2_validate_counter_packet
@ -------------------------------------------------------------
@ Validate rx_buf and copy its body into body_buf.
@
@ Checks performed (in order):
@   1) STX present at byte 0
@   2) NUL terminator at expected position (LEN - 3)
@   3) ETX present at expected position (LEN - 2)
@   4) BCC checksum of entire packet equals zero
@   5) Body begins with "COUNTER = "
@   6) At least one digit follows the prefix
@   7) All remaining characters are ASCII digits ('0'-'9')
@
@   + Output: R0 = 1 if valid, 0 if invalid
@   + Modifies: R1, R2, R3, R4, R5, R6, R7
.type ex5_b2_validate_counter_packet, %function
ex5_b2_validate_counter_packet:
    PUSH {R4, R5, R6, R7, LR}

    LDR R1, =rx_buf
    LDRB R2, [R1, #1]               @ total packet length

    @ Check 1: STX
    LDRB R3, [R1]
    CMP R3, #STX
    BNE ex5_b2_packet_invalid

    @ Check 2: NUL terminator position depends on checksum size
    @ BCC appends 1 byte  -> NUL at LEN-3, ETX at LEN-2
    @ CRC16 appends 2 bytes -> NUL at LEN-4, ETX at LEN-3
.if USE_CRC16
    SUBS R4, R2, #4
.else
    SUBS R4, R2, #3
.endif
    LDRB R3, [R1, R4]
    CMP R3, #0
    BNE ex5_b2_packet_invalid

    @ Check 3: ETX immediately follows NUL (always +1 from NUL position)
    ADDS R4, R4, #1
    LDRB R3, [R1, R4]
    CMP R3, #ETX
    BNE ex5_b2_packet_invalid

    @ Check 4: verify checksum (algorithm selected at build time)
.if USE_CRC16
    BL str_verify_crc16
.else
    BL str_verify_checksum
.endif
    CMP R3, #0
    BNE ex5_b2_packet_invalid

    @ Copy body (rx_buf+2 up to but not including ETX) into body_buf.
    @ The NUL terminator is included in the copy since it precedes ETX.
    LDR R4, =rx_buf
    ADD R4, R4, #2
    LDR R5, =body_buf

ex5_b2_copy_loop:
    LDRB R6, [R4], #1
    CMP R6, #ETX
    BEQ ex5_b2_check_prefix
    STRB R6, [R5], #1
    B ex5_b2_copy_loop

    @ Check 5: body must start with "COUNTER = "
ex5_b2_check_prefix:
    LDR R4, =body_buf
    LDR R5, =counter_prefix

ex5_b2_prefix_loop:
    LDRB R6, [R5], #1
    CMP R6, #0                      @ reached end of prefix string
    BEQ ex5_b2_check_digits

    LDRB R7, [R4], #1
    CMP R7, R6
    BNE ex5_b2_packet_invalid
    B ex5_b2_prefix_loop

    @ Check 6: at least one digit must follow the prefix
ex5_b2_check_digits:
    LDRB R6, [R4]
    CMP R6, #0
    BEQ ex5_b2_packet_invalid       @ empty digits field

    @ Check 7: every remaining character must be '0'-'9'
ex5_b2_digit_loop:
    LDRB R6, [R4], #1
    CMP R6, #0
    BEQ ex5_b2_packet_valid         @ NUL terminator - done

    CMP R6, #0x30                   @ below '0'
    BLT ex5_b2_packet_invalid
    CMP R6, #0x39                   @ above '9'
    BGT ex5_b2_packet_invalid
    B ex5_b2_digit_loop

ex5_b2_packet_valid:
    MOV R0, #1
    POP {R4, R5, R6, R7, PC}

ex5_b2_packet_invalid:
    MOV R0, #0
    POP {R4, R5, R6, R7, PC}


@ -------------------------------------------------------------
@ ex5_b2_send_framed_reply
@ -------------------------------------------------------------
@ Build and transmit a framed ACK or NAK packet on UART4.
@ Uses resp_src_b2 as the single-char source and resp_buf_b2
@ as the output frame buffer.
@   + Input:  R0 = ACK or NAK byte value
@   + Output: none
@   + Modifies: R0, R1, R2, R3, R4
.type ex5_b2_send_framed_reply, %function
ex5_b2_send_framed_reply:
    PUSH {R4, LR}
    MOV R4, R0                      @ save payload byte

    @ Write payload byte + NUL into the source buffer
    LDR R0, =resp_src_b2
    STRB R4, [R0]
    MOV R3, #0
    STRB R3, [R0, #1]

    @ Frame it: STX | LEN | payload | NUL | ETX | checksum
    LDR R1, =resp_buf_b2
    BL str_reset_counter
    BL str_concat
.if USE_CRC16
    BL str_crc16_checksum           @ CRC16-CCITT: appends 2 bytes
.else
    BL str_checksum                 @ BCC XOR: appends 1 byte
.endif

    @ Transmit; packet length is at the LENGTH_BYTE_IDX offset
    LDR R1, =resp_buf_b2
    LDRB R2, [R1, #LENGTH_BYTE_IDX]
    BL uart_transmit

    POP {R4, PC}


@ -------------------------------------------------------------
@ ex5_b2_flash_3x
@ -------------------------------------------------------------
@ Flash all LEDs 3 times: 0.5 s ON then 0.5 s OFF each cycle.
@   + Output: none
@   + Modifies: R0, R5, R7
.type ex5_b2_flash_3x, %function
ex5_b2_flash_3x:
    PUSH {R5, R7, LR}
    MOV R5, #3

ex5_b2_flash_loop:
    MOV R7, #0xFF
    BL led_set_pattern
    LDR R0, =LED_HALF_PERIOD_MS
    BL timer_delay_arr

    MOV R7, #0x00
    BL led_set_pattern
    LDR R0, =LED_HALF_PERIOD_MS
    BL timer_delay_arr

    SUBS R5, R5, #1
    BNE ex5_b2_flash_loop

    POP {R5, R7, PC}


@ -------------------------------------------------------------
@ str_to_int
@ -------------------------------------------------------------
@ Convert a NUL-terminated ASCII decimal string to an integer.
@   + Input:  R1 = pointer to string
@   + Output: R0 = parsed integer value
@   + Modifies: R2, R3
.type str_to_int, %function
str_to_int:
    PUSH {R2, R3, LR}
    MOV R0, #0
    MOV R3, #10

str_to_int_loop:
    LDRB R2, [R1], #1
    CMP R2, #0                      @ NUL terminator
    BEQ str_to_int_done

    @ Shift accumulated value left one decimal place and add digit
    SUB R2, R2, #0x30               @ ASCII to digit value
    MUL R0, R0, R3
    ADD R0, R0, R2
    B str_to_int_loop

str_to_int_done:
    POP {R2, R3, PC}
