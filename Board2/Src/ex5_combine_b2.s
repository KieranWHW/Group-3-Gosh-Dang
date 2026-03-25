.syntax unified
.thumb
.thumb_func

#include "definitions.s"

.equ DELAY_500MS_MS,      500
.equ MIN_COUNTER_PKT_LEN, 16
.equ MAX_COUNTER_PKT_LEN, 32

.data
rx_buf:          .space 32
body_buf:        .space 32
resp_src_b2:     .space 2
resp_buf_b2:     .space 16
counter_prefix:  .asciz "COUNTER = "

.text

.type ex5_board2_run_demo, %function
ex5_board2_run_demo:
    LDR R0, =7999
    BL timer_set_psc
    BL timer_start

    @ optional startup settle delay
    LDR R0, =500
    BL timer_delay_arr

    MOV R7, #0
    BL led_set_pattern

ex5_b2_loop:
    LDR R6, =UART4

ex5_b2_wait_rxne:
    LDR R0, [R6, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BEQ ex5_b2_wait_rxne

    @ phase 1: receive STX + length
    LDR R1, =rx_buf
    MOV R2, #2
    BL uart_receive_packet

    @ quick length sanity check
    LDR R1, =rx_buf
    LDRB R2, [R1]
    CMP R2, #STX
    BNE ex5_b2_invalid

    LDRB R2, [R1, #1]
    CMP R2, #MIN_COUNTER_PKT_LEN
    BLT ex5_b2_invalid
    CMP R2, #MAX_COUNTER_PKT_LEN
    BGT ex5_b2_invalid

    @ phase 2: receive remaining bytes
    SUBS R2, R2, #2
    ADD R1, R1, #2
    BL uart_receive_packet

    @ local validation
    BL ex5_b2_validate_counter_packet
    CMP R0, #1
    BNE ex5_b2_invalid

    @ valid packet -> display counter and send framed ACK
    LDR R1, =body_buf
    ADD R1, R1, #10
    BL str_to_int

    AND R7, R0, #0xFF
    BL led_set_pattern

    MOV R0, #ACK
    BL ex5_b2_send_framed_reply
    B ex5_b2_loop

ex5_b2_invalid:
    MOV R0, #NAK
    BL ex5_b2_send_framed_reply
    BL ex5_b2_flash_3x
    B ex5_b2_loop


@ Validate rx_buf and copy body to body_buf
@ Returns R0 = 1 valid, 0 invalid
.type ex5_b2_validate_counter_packet, %function
ex5_b2_validate_counter_packet:
    PUSH {R4, R5, R6, R7, LR}

    LDR R1, =rx_buf
    LDRB R2, [R1, #1]

    LDRB R3, [R1]
    CMP R3, #STX
    BNE ex5_b2_packet_invalid

    SUBS R4, R2, #3
    LDRB R3, [R1, R4]
    CMP R3, #0
    BNE ex5_b2_packet_invalid

    ADDS R4, R4, #1
    LDRB R3, [R1, R4]
    CMP R3, #ETX
    BNE ex5_b2_packet_invalid

    BL str_verify_checksum
    CMP R3, #0
    BNE ex5_b2_packet_invalid

    @ copy body from rx_buf+2 until ETX
    LDR R4, =rx_buf
    ADD R4, R4, #2
    LDR R5, =body_buf

ex5_b2_copy_loop:
    LDRB R6, [R4], #1
    CMP R6, #ETX
    BEQ ex5_b2_check_prefix
    STRB R6, [R5], #1
    B ex5_b2_copy_loop

ex5_b2_check_prefix:
    LDR R4, =body_buf
    LDR R5, =counter_prefix

ex5_b2_prefix_loop:
    LDRB R6, [R5], #1
    CMP R6, #0
    BEQ ex5_b2_check_digits

    LDRB R7, [R4], #1
    CMP R7, R6
    BNE ex5_b2_packet_invalid
    B ex5_b2_prefix_loop

ex5_b2_check_digits:
    LDRB R6, [R4]
    CMP R6, #0
    BEQ ex5_b2_packet_invalid

ex5_b2_digit_loop:
    LDRB R6, [R4], #1
    CMP R6, #0
    BEQ ex5_b2_packet_valid

    CMP R6, #0x30
    BLT ex5_b2_packet_invalid
    CMP R6, #0x39
    BGT ex5_b2_packet_invalid
    B ex5_b2_digit_loop

ex5_b2_packet_valid:
    MOV R0, #1
    POP {R4, R5, R6, R7, PC}

ex5_b2_packet_invalid:
    MOV R0, #0
    POP {R4, R5, R6, R7, PC}


@ Send framed ACK/NAK packet
@ Input: R0 = ACK or NAK
.type ex5_b2_send_framed_reply, %function
ex5_b2_send_framed_reply:
    PUSH {R4, LR}
    MOV R4, R0

    LDR R0, =resp_src_b2
    STRB R4, [R0]
    MOV R3, #0
    STRB R3, [R0, #1]

    LDR R1, =resp_buf_b2
    BL str_reset_counter
    BL str_concat
    BL str_checksum

    LDR R1, =resp_buf_b2
    LDRB R2, [R1, #LENGTH_BYTE_IDX]
    BL uart_transmit

    POP {R4, PC}


.type ex5_b2_flash_3x, %function
ex5_b2_flash_3x:
    PUSH {R5, R7, LR}
    MOV R5, #3

ex5_b2_flash_loop:
    MOV R7, #0xFF
    BL led_set_pattern
    LDR R0, =DELAY_500MS_MS
    BL timer_delay_arr

    MOV R7, #0x00
    BL led_set_pattern
    LDR R0, =DELAY_500MS_MS
    BL timer_delay_arr

    SUBS R5, R5, #1
    BNE ex5_b2_flash_loop

    POP {R5, R7, PC}


.type str_to_int, %function
str_to_int:
    PUSH {R2, R3, LR}
    MOV R0, #0
    MOV R3, #10

str_to_int_loop:
    LDRB R2, [R1], #1
    CMP R2, #0
    BEQ str_to_int_done
    SUB R2, R2, #0x30
    MUL R0, R0, R3
    ADD R0, R0, R2
    B str_to_int_loop

str_to_int_done:
    POP {R2, R3, PC}
