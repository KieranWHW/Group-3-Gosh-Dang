.syntax unified
.thumb
.thumb_func

#include "definitions.s"

.data
ack_nak_src:  .space 2             @ ACK/NAK byte + NUL terminator
response_buf: .space 16            @ framed ACK/NAK response packet

.text
@ =============================================================
@ UART helper module
@ =============================================================
@ All functions in this module are prefixed with "uart_".


@ -------------------------------------------------------------
@ uart_transmit
@ -------------------------------------------------------------
@ Transmit a packet over UART4 one byte at a time.
@   + Input:  R1 = packet buffer address
@             R2 = number of bytes to send
@   + Output: none
@   + Modifies: R0, R3, R5, R6
.type uart_transmit, %function
uart_transmit:
    PUSH {R6, LR}
    LDR R0, =UART4
    MOV R6, #0

uart_transmit_loop:
    LDR R3, [R0, #UART_ISR]
    ANDS R3, R3, #(1 << TXE)
    BEQ uart_transmit_loop

    LDRB R5, [R1], #1
    STRB R5, [R0, #UART_TDR]

    ADDS R6, R6, #1
    CMP R6, R2
    BNE uart_transmit_loop

    POP {R6, PC}


@ -------------------------------------------------------------
@ uart_read_check
@ -------------------------------------------------------------
@ Validate a received UART packet and copy its string body.
@
@ Validation checks:
@   1) STX present
@   2) NUL terminator at expected index
@   3) ETX at expected index
@   4) checksum valid
@   5) copied byte count matches packet length
@
@ A framed ACK or NAK reply is transmitted on UART4.
@   + Input:  R1 = received packet address
@             R2 = destination buffer address for string body
@   + Output: R0 = ACK if valid, NAK if invalid
@             destination buffer filled if valid
@   + Modifies: R1, R2, R3, R4, R5, R8, R9, R10
.type uart_read_check, %function
uart_read_check:
    PUSH {LR}
    MOV R10, R2                    @ save destination buffer pointer

    @ Check 1: STX must be the first byte.
    LDRB R3, [R1]
    CMP R3, #STX
    BNE uart_nak_response

    @ Read total packet length.
    LDRB R2, [R1, #1]

    @ Check 2: packet must contain a NUL terminator at length - 3.
    SUBS R8, R2, #3
    LDRB R3, [R1, R8]
    CMP R3, #0x00
    BNE uart_nak_response

    @ Check 3: ETX must follow the NUL terminator.
    ADDS R8, R8, #1
    LDRB R3, [R1, R8]
    CMP R3, #ETX
    BNE uart_nak_response

    @ Check 4: XOR of whole packet including checksum must be zero.
    MOV R5, #0x00
    MOV R3, #0x00
    BL str_verify_checksum
    CMP R3, #0x00
    BNE uart_nak_response

    @ Copy the string body to the destination buffer.
    MOV R9, R2                     @ preserve total length
    MOV R2, R10                    @ restore destination buffer pointer
    ADD R1, R1, #2                 @ point to body start
    MOV R4, #0x00                  @ byte counter

uart_read_loop:
    LDRB R5, [R1, R4]
    CMP R5, #ETX
    BEQ uart_read_check_count

    STRB R5, [R2], #1
    ADDS R4, R4, #1
    B uart_read_loop

uart_read_check_count:
    @ R4 includes the copied body bytes, including the NUL terminator.
    @ Add 4 for STX + Length + ETX + Checksum.
    ADDS R4, R4, #4
    CMP R4, R9
    BNE uart_nak_response

    B uart_ack_response


@ -------------------------------------------------------------
@ uart_ack_response / uart_nak_response
@ -------------------------------------------------------------
@ Build and send a framed ACK / NAK packet.
uart_ack_response:
    MOV R6, #ACK
    B uart_build_response

uart_nak_response:
    MOV R6, #NAK

uart_build_response:
    @ Build a temporary NUL-terminated 1-byte source string.
    LDR R0, =ack_nak_src
    STRB R6, [R0]
    MOV R7, #0x00
    STRB R7, [R0, #1]

    @ Frame the response packet.
    LDR R1, =response_buf
    BL str_reset_counter
    BL str_concat
    BL str_checksum

    @ Transmit the response.
    LDR R1, =response_buf
    BL uart_transmit

    MOV R0, R6
    POP {PC}


@ -------------------------------------------------------------
@ uart_receive_packet
@ -------------------------------------------------------------
@ Receive exactly R2 bytes from UART4 RX into the buffer at R1.
@ This is a polling implementation: it blocks until each byte arrives.
@   + Input:  R1 = destination buffer address
@             R2 = number of bytes to receive
@   + Output: destination buffer filled with received bytes
@   + Modifies: R0, R3, R5, R6
.type uart_receive_packet, %function
uart_receive_packet:
    PUSH {LR}
    LDR R0, =UART4
    MOV R6, #0

uart_receive_packet_loop:
    LDR R3, [R0, #UART_ISR]
    ANDS R3, R3, #(1 << RXNE)
    BEQ uart_receive_packet_loop

    LDRB R5, [R0, #UART_RDR]
    STRB R5, [R1], #1

    ADDS R6, R6, #1
    CMP R6, R2
    BNE uart_receive_packet_loop

    POP {PC}
