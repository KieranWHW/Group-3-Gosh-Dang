.syntax unified
.thumb
.thumb_func

#include "definitions.s"

@ =============================================
@ Exercise 5 — Board 1
@ =============================================
@ Sends "COUNTER = XXX" every 1 second as a UART packet.
@ Waits up to 5 seconds for ACK/NAK from Board 2.
@ ACK       -> increment counter and continue
@ NAK/timeout -> flash LEDs 3 times and reset counter to 0
@
@ This version keeps the older 5s response-window structure,
@ but adds:
@   - 0.5s startup delay
@   - UART RX error clear + flush before each send

.equ BOOT_DELAY_MS,   500
.equ DELAY_5KLOOP,    5000
.equ DELAY_1KLOOP,    1000
.equ DELAY_500MS_MS,  500

.data
counter_buf: .ascii "COUNTER = "
             .space 6

tx_buf:      .space 32
rx_buf:      .space 32

.text

@ -------------------------------------------------
@ Main loop
@ -------------------------------------------------
.type ex5_run_demo, %function
ex5_run_demo:
    MOV R0, #7999
    BL timer_set_psc
    BL timer_start

    @ let both boards finish startup / reset cleanly
    LDR R0, =BOOT_DELAY_MS
    BL timer_delay_arr

    @ clear any stale UART state before first transaction
    BL ex5_uart_rx_recover

    MOV R4, #0

ex5_transmit_loop:
    @ Step 1: wait 1 second before each transmission
    LDR R0, =DELAY_1KLOOP
    BL timer_delay_arr

    @ Step 2: write counter digits into counter_buf at offset 10
    LDR R1, =counter_buf
    ADD R1, R1, #10
    MOV R0, R4
    BL int_to_str

    @ Step 3: packet-frame counter_buf into tx_buf
    LDR R0, =counter_buf
    LDR R1, =tx_buf
    BL str_reset_counter
    BL str_concat
    BL str_checksum

    @ Step 4: clear RX/error state before sending
    BL ex5_uart_rx_recover

    @ Step 5: transmit the packet
    LDR R1, =tx_buf
    LDRB R2, [R1, #LENGTH_BYTE_IDX]
    BL uart_transmit

    @ Step 6: wait up to 5s for ACK/NAK from Board 2
    BL ex5_wait_ack

    CMP R0, #ACK
    BNE ex5_nak_or_timeout

    @ ACK received
    ADD R4, R4, #1
    AND R4, R4, #0xFF
    B ex5_transmit_loop

ex5_nak_or_timeout:
    BL ex5_flash_3x
    MOV R4, #0
    B ex5_transmit_loop


@ -------------------------------------------------
@ Wait up to 5s for a framed ACK/NAK packet
@ Returns:
@   R0 = ACK / NAK / 0xFF (timeout or malformed)
@ -------------------------------------------------
.type ex5_wait_ack, %function
ex5_wait_ack:
    PUSH {R5, R6, LR}

    @ fresh 5s timeout window on TIM2
    LDR R5, =TIM2
    LDR R6, =DELAY_5KLOOP
    STR R6, [R5, #TIM_ARR]

    MOV R6, #(1 << TIM_UG)
    STR R6, [R5, #TIM_EGR]

    LDR R6, [R5, #TIM_SR]
    BIC R6, R6, #(1 << TIM_UIF)
    STR R6, [R5, #TIM_SR]

ex5_wait_loop:
    @ while waiting, clear UART error flags if needed
    BL ex5_uart_check_and_clear_errors

    @ check RXNE first
    LDR R6, =UART4
    LDR R0, [R6, #UART_ISR]
    ANDS R0, R0, #(1 << RXNE)
    BNE ex5_byte_received

    @ then check 5s timeout
    LDR R6, =TIM2
    LDR R0, [R6, #TIM_SR]
    ANDS R0, R0, #(1 << TIM_UIF)
    BNE ex5_timeout

    B ex5_wait_loop

ex5_byte_received:
    @ phase 1: read STX + Len
    LDR R1, =rx_buf
    MOV R2, #2
    BL uart_receive_packet

    @ sanity-check length before phase 2
    LDR R1, =rx_buf
    LDRB R2, [R1]
    CMP R2, #STX
    BNE ex5_bad_reply

    LDRB R2, [R1, #1]
    CMP R2, #4
    BLT ex5_bad_reply
    CMP R2, #16
    BGT ex5_bad_reply

    @ phase 2: read remaining bytes
    SUBS R2, R2, #2
    ADD R1, R1, #2
    BL uart_receive_packet

    @ ACK / NAK byte is at index 2
    LDR R1, =rx_buf
    LDRB R0, [R1, #2]

    POP {R5, R6, PC}

ex5_bad_reply:
    MOV R0, #0xFF
    POP {R5, R6, PC}

ex5_timeout:
    MOV R0, #0xFF
    POP {R5, R6, PC}


@ -------------------------------------------------
@ Flash all LEDs 3 times with 0.5s on / 0.5s off
@ -------------------------------------------------
.type ex5_flash_3x, %function
ex5_flash_3x:
    PUSH {R5, R7, LR}
    MOV R5, #3

ex5_flash_loop:
    MOV R7, #0xFF
    BL led_set_pattern
    LDR R0, =DELAY_500MS_MS
    BL timer_delay_arr

    MOV R7, #0x00
    BL led_set_pattern
    LDR R0, =DELAY_500MS_MS
    BL timer_delay_arr

    SUBS R5, R5, #1
    BNE ex5_flash_loop

    POP {R5, R7, PC}


@ -------------------------------------------------
@ Clear UART RX errors and flush stale bytes
@ -------------------------------------------------
.type ex5_uart_rx_recover, %function
ex5_uart_rx_recover:
    PUSH {R5, R6, LR}
    LDR R5, =UART4

    @ clear UART error flags if present
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


@ -------------------------------------------------
@ During the wait loop, clear UART receive errors if they appear
@ -------------------------------------------------
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


@ -------------------------------------------------
@ Convert unsigned integer in R0 to ASCII string at R1
@ -------------------------------------------------
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
    MOV R3, #0
    MOV R5, #10

int_to_str_digit_loop:
    UDIV R4, R0, R5
    MLS  R2, R4, R5, R0
    ADD  R2, R2, #0x30
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
